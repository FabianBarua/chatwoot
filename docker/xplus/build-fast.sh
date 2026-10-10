#!/usr/bin/env bash
# Compila chatwoot:xp-local en pocos minutos: código + assets del commit actual encima de la
# última imagen publicada (gems ya instaladas). Sirve cuando no cambió el Gemfile.lock.
#
#   docker/xplus/build-fast.sh                 # compila HEAD
#   docker/xplus/build-fast.sh --push          # además publica en GHCR
#   docker/xplus/build-fast.sh --base ghcr.io/fabianbarua/chatwoot:v4.18.0-xp-abc1234
#
# Igual que build.sh, compila desde un clon limpio (LF) y solo entra lo commiteado.
set -euo pipefail
export MSYS_NO_PATHCONV=1

IMAGE="ghcr.io/fabianbarua/chatwoot"
BASE="$IMAGE:v4.18.0-xp"
PUSH=0

while [ $# -gt 0 ]; do
  case "$1" in
    --push) PUSH=1 ;;
    --base) BASE="$2"; shift ;;
    *) echo "Opción desconocida: $1" >&2; exit 1 ;;
  esac
  shift
done

ROOT="$(git rev-parse --show-toplevel)"
SHA="$(git -C "$ROOT" rev-parse --short=7 HEAD)"
BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD | tr '/' '-')"

if [ -n "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ]; then
  echo "Aviso: hay cambios sin commitear; la imagen se compila desde $SHA y no los incluye." >&2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Clon LF de $SHA"
git clone -q -c core.autocrlf=false "$ROOT" "$WORK/src"
git -C "$WORK/src" checkout -q "$SHA"

echo "==> Base: $BASE"
docker pull "$BASE"

echo "==> docker build rápido ($IMAGE:$BRANCH y $IMAGE:$BRANCH-$SHA)"
DOCKER_BUILDKIT=1 docker build -f "$ROOT/docker/xplus/Dockerfile.fast" \
  --build-arg BASE="$BASE" \
  --build-arg GIT_SHA="$(git -C "$WORK/src" rev-parse HEAD)" \
  -t chatwoot:xp-local \
  -t "$IMAGE:$BRANCH" \
  -t "$IMAGE:$BRANCH-$SHA" \
  "$WORK/src"

echo "Commit dentro de la imagen: $(docker run --rm --entrypoint cat chatwoot:xp-local /app/.git_sha)"

if [ "$PUSH" = 1 ]; then
  echo "==> Publicando en GHCR"
  docker push "$IMAGE:$BRANCH"
  docker push "$IMAGE:$BRANCH-$SHA"
fi

echo "Listo: $IMAGE:$BRANCH-$SHA"
