#!/usr/bin/env bash
# One-time project setup: APIs, Artifact Registry, bearer-token secret, IAM.
# Safe to re-run.
set -euo pipefail
source "$(dirname "$0")/config.sh"

gcloud config set project "$PROJECT_ID"

echo "==> Enabling APIs"
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com

echo "==> Artifact Registry repository"
if ! gcloud artifacts repositories describe "$REPO" --location "$REGION" >/dev/null 2>&1; then
  gcloud artifacts repositories create "$REPO" \
    --repository-format docker --location "$REGION" \
    --description "EUDAMED MCP images"
fi

echo "==> Bearer token secret"
if ! gcloud secrets describe "$TOKEN_SECRET" >/dev/null 2>&1; then
  TOKEN="$(openssl rand -hex 32)"
  printf '%s' "$TOKEN" | gcloud secrets create "$TOKEN_SECRET" \
    --replication-policy automatic --data-file=-
  echo "Generated token (shown once, store it for your MCP client):"
  echo "  $TOKEN"
else
  echo "Secret $TOKEN_SECRET already exists, keeping it."
fi

echo "==> IAM"
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format 'value(projectNumber)')"
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
# Cloud Run runtime identity reads the token; Cloud Build identity builds and pushes images.
gcloud secrets add-iam-policy-binding "$TOKEN_SECRET" \
  --member "serviceAccount:${COMPUTE_SA}" --role roles/secretmanager.secretAccessor >/dev/null
for role in roles/cloudbuild.builds.builder roles/artifactregistry.writer roles/logging.logWriter; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member "serviceAccount:${COMPUTE_SA}" --role "$role" --condition=None >/dev/null
done

echo "Setup done. Next: scripts/gcp/deploy.sh"
