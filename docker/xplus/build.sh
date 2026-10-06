#!/usr/bin/env bash
# Compila la imagen Xplus desde un commit, siempre con fin de línea LF.
#
#   docker/xplus/build.sh            # compila HEAD y etiqueta chatwoot:xp-local + GHCR
#   docker/xplus/build.sh --push     # además publica en GHCR
#   docker/xplus/build.sh --ref a318591 --push
#
# Compila desde un clon limpio del repo y no desde la carpeta de trabajo: en Windows
# la copia de trabajo puede tener CRLF y el contenedor no arranca
# ("exec docker/entrypoints/rails.sh: no such file or directory").
# Solo entra lo que está commiteado.
set -euo pipefail
export MSYS_NO_PATHCONV=1

IMAGE="ghcr.io/fabianbarua/chatwoot"
REF="HEAD"
PUSH=0

while [ $# -gt 0 ]; do
  case "$1" in
    --push) PUSH=1 ;;
    --ref) REF="$2"; shift ;;
    *) echo "Opción desconocida: $1" >&2; exit 1 ;;
  esac
  shift
done

ROOT="$(git rev-parse --show-toplevel)"
SHA="$(git -C "$ROOT" rev-parse --short=7 "$REF")"
BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD | tr '/' '-')"

if [ -n "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ]; then
  echo "Aviso: hay cambios sin commitear; la imagen se compila desde $SHA y no los incluye." >&2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Clon LF de $SHA"
git clone -q -c core.autocrlf=false "$ROOT" "$WORK/src"
git -C "$WORK/src" checkout -q "$SHA"

echo "==> docker build ($IMAGE:$BRANCH y $IMAGE:$BRANCH-$SHA)"
DOCKER_BUILDKIT=1 docker build -f "$WORK/src/docker/Dockerfile" \
  -t chatwoot:xp-local \
  -t "$IMAGE:$BRANCH" \
  -t "$IMAGE:$BRANCH-$SHA" \
  "$WORK/src"

echo "==> Comprobando que el entrypoint no tenga CRLF"
if docker run --rm --entrypoint sh chatwoot:xp-local -c "grep -q \$(printf '\r') /app/docker/entrypoints/rails.sh"; then
  echo "ERROR: la imagen tiene CRLF en docker/entrypoints/rails.sh" >&2
  exit 1
fi
echo "Commit dentro de la imagen: $(docker run --rm --entrypoint cat chatwoot:xp-local /app/.git_sha)"

if [ "$PUSH" = 1 ]; then
  echo "==> Publicando en GHCR"
  docker push "$IMAGE:$BRANCH"
  docker push "$IMAGE:$BRANCH-$SHA"
fi

echo "Listo: $IMAGE:$BRANCH-$SHA"
