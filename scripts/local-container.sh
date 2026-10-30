#!/usr/bin/env bash
# Build and run the server locally with Apple's `container` CLI.
# Usage: scripts/local-container.sh [build|run|stop|logs|all]   (default: all = build + run)
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="${NAME:-eudamed-mcp}"
IMAGE="${IMAGE:-eudamed-mcp:local}"
HOST_PORT="${HOST_PORT:-8080}"
TOKEN="${EUDAMED_MCP_TOKEN:-}"   # empty = open endpoint

build() {
  container system start >/dev/null 2>&1 || true
  container build --tag "$IMAGE" --file Dockerfile .
}

stop() {
  container stop "$NAME" >/dev/null 2>&1 || true
  container delete "$NAME" >/dev/null 2>&1 || true
}

run() {
  stop
  container run --detach --name "$NAME" \
    --publish "127.0.0.1:${HOST_PORT}:8080" \
    --env "EUDAMED_MCP_TOKEN=${TOKEN}" \
    "$IMAGE"
  echo "MCP endpoint: http://localhost:${HOST_PORT}/mcp"
  echo "Health check: http://localhost:${HOST_PORT}/health"
}

case "${1:-all}" in
  build) build ;;
  run)   run ;;
  stop)  stop ;;
  logs)  container logs --follow "$NAME" ;;
  all)   build; run ;;
  *)     echo "usage: $0 [build|run|stop|logs|all]" >&2; exit 2 ;;
esac
