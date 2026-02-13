#!/usr/bin/env bash
#
# Creates OIDC federated credentials on an existing App Registration
# for GitHub Actions (main branch, pull requests, and environments).
#
# Usage:
#   ./create-federated-credentials.sh <OWNER/REPO> [APP_CLIENT_ID]
#
# Arguments:
#   OWNER/REPO     - GitHub repository (e.g. myorg/bicep-labs)
#   APP_CLIENT_ID  - App registration client ID (optional if only one app exists)
#
# If APP_CLIENT_ID is omitted, the script looks up "github-bicep-labs" by display name.
#
# Prerequisites:
#   - Azure CLI installed and logged in (az login)
#   - App registration already created (run create-app-registration.sh first)

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <OWNER/REPO> [APP_CLIENT_ID]"
  echo "  e.g. $0 myorg/bicep-labs"
  exit 1
fi

GITHUB_REPO="$1"

if [[ $# -ge 2 ]]; then
  APP_ID="$2"
else
  echo "==> Looking up app registration 'github-bicep-labs'"
  APP_ID=$(az ad app list --display-name "github-bicep-labs" --query "[0].appId" -o tsv)
  if [[ -z "${APP_ID}" ]]; then
    echo "Error: App registration 'github-bicep-labs' not found. Run create-app-registration.sh first or pass the APP_CLIENT_ID."
    exit 1
  fi
fi

echo "==> App (client) ID: ${APP_ID}"
echo "    GitHub repo:     ${GITHUB_REPO}"

# Get the app object ID (needed for federated credential API)
APP_OBJECT_ID=$(az ad app show --id "${APP_ID}" --query id -o tsv)

echo ""
echo "==> Creating federated credential for main branch"
az ad app federated-credential create \
  --id "${APP_OBJECT_ID}" \
  --parameters "{
    \"name\": \"github-main\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_REPO}:ref:refs/heads/main\",
    \"audiences\": [\"api://AzureADTokenExchange\"],
    \"description\": \"GitHub Actions - main branch\"
  }" \
  --output none
echo "    ✓ main branch credential created"

echo ""
echo "==> Creating federated credential for pull requests"
az ad app federated-credential create \
  --id "${APP_OBJECT_ID}" \
  --parameters "{
    \"name\": \"github-pr\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_REPO}:pull_request\",
    \"audiences\": [\"api://AzureADTokenExchange\"],
    \"description\": \"GitHub Actions - pull requests\"
  }" \
  --output none
echo "    ✓ pull request credential created"

echo ""
echo "==> Creating federated credentials for environments (dev, staging, prod)"
for ENV_NAME in dev staging prod; do
  az ad app federated-credential create \
    --id "${APP_OBJECT_ID}" \
    --parameters "{
      \"name\": \"github-env-${ENV_NAME}\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"repo:${GITHUB_REPO}:environment:${ENV_NAME}\",
      \"audiences\": [\"api://AzureADTokenExchange\"],
      \"description\": \"GitHub Actions - ${ENV_NAME} environment\"
    }" \
    --output none
  echo "    ✓ ${ENV_NAME} environment credential created"
done

echo ""
echo "============================================"
echo " Federated credentials created successfully"
echo "============================================"
echo ""
echo " Credentials configured for:"
echo "   • repo:${GITHUB_REPO}:ref:refs/heads/main"
echo "   • repo:${GITHUB_REPO}:pull_request"
echo "   • repo:${GITHUB_REPO}:environment:dev"
echo "   • repo:${GITHUB_REPO}:environment:staging"
echo "   • repo:${GITHUB_REPO}:environment:prod"
echo ""
echo " The GitHub Actions workflows can now authenticate to Azure using OIDC."
echo ""
