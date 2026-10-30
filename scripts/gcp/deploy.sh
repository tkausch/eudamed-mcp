#!/usr/bin/env bash
# Build the image with Cloud Build and deploy it to Cloud Run.
# Usage: scripts/gcp/deploy.sh [--no-token]
#   --no-token  deploy an open endpoint: no bearer token, anyone with the URL can call /mcp.
set -euo pipefail
source "$(dirname "$0")/config.sh"
cd "$(dirname "$0")/../.."

case "${1:-}" in
  "")         SECRET_FLAG=(--set-secrets "EUDAMED_MCP_TOKEN=${TOKEN_SECRET}:latest") ;;
  --no-token) SECRET_FLAG=(--remove-secrets EUDAMED_MCP_TOKEN) ;;
  *)          echo "usage: $0 [--no-token]" >&2; exit 2 ;;
esac

TAG="$(git rev-parse --short HEAD 2>/dev/null || date +%s)"

echo "==> Building ${IMAGE}:${TAG}"
# Swift release builds are slow on the default machine; use a bigger one.
gcloud builds submit . --project "$PROJECT_ID" --region "$REGION" \
  --tag "${IMAGE}:${TAG}" --machine-type e2-highcpu-8 --timeout 1800s

echo "==> Deploying ${SERVICE}"
gcloud run deploy "$SERVICE" \
  --project "$PROJECT_ID" --region "$REGION" \
  --image "${IMAGE}:${TAG}" \
  --allow-unauthenticated \
  --port 8080 \
  --cpu 1 --memory 512Mi \
  --min-instances 0 --max-instances 1 --timeout 60s \
  "${SECRET_FLAG[@]}"

URL="$(gcloud run services describe "$SERVICE" --project "$PROJECT_ID" --region "$REGION" --format 'value(status.url)')"

echo
echo "MCP endpoint: ${URL}/mcp"
echo "Health check: ${URL}/health"
if [[ "${1:-}" == "--no-token" ]]; then
  echo "Token:        none (open endpoint)"
else
  echo "Token:        gcloud secrets versions access latest --secret ${TOKEN_SECRET}"
fi
