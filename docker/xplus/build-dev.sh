#!/usr/bin/env bash
# Builds chatwoot:xp-dev (rubocop and rspec) on top of the local production image instead of a full
# docker/Dockerfile build: the production image already has gcc and the production gems, so only the
# development and test gems get installed. Use it when the full build takes Docker Desktop down.
#
#   docker/xplus/build-dev.sh                       # on top of chatwoot:xp-local
#   docker/xplus/build-dev.sh --base <image>        # on top of another image
set -euo pipefail

BASE="chatwoot:xp-local"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONTEXT="$(mktemp -d)"
trap 'rm -rf "$CONTEXT"' EXIT

cp "$ROOT/Gemfile" "$ROOT/Gemfile.lock" "$CONTEXT/"
cat > "$CONTEXT/Dockerfile" <<EOF
FROM $BASE
USER root
ENV BUNDLE_WITHOUT="" RAILS_ENV=development EXECJS_RUNTIME=Node
WORKDIR /app
COPY Gemfile Gemfile.lock /app/
RUN bundle install --jobs 4 && bundle exec rubocop --version
EOF

# Docker on Windows needs the Windows form of the context path (Git Bash would rewrite it otherwise)
docker build -t chatwoot:xp-dev -f "$CONTEXT/Dockerfile" "$(cd "$CONTEXT" && pwd -W 2>/dev/null || pwd)"
echo "chatwoot:xp-dev ready (base: $BASE)"
