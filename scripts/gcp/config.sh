# Shared settings for the Cloud Run scripts. Override any value via the environment.
PROJECT_ID="${PROJECT_ID:-eudamed-mcp-513210}"
REGION="${REGION:-europe-west6}"            # Zurich
SERVICE="${SERVICE:-eudamed-mcp}"
REPO="${REPO:-eudamed-mcp}"                 # Artifact Registry repository
TOKEN_SECRET="${TOKEN_SECRET:-eudamed-mcp-token}"
IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/${SERVICE}"
