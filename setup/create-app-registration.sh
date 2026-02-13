#!/usr/bin/env bash
#
# Creates an Azure AD App Registration and Service Principal for GitHub Actions.
# Assigns Contributor + User Access Administrator roles on the target subscription.
#
# Usage:
#   ./create-app-registration.sh [APP_DISPLAY_NAME]
#
# Defaults:
#   APP_DISPLAY_NAME = "github-bicep-labs"
#
# Prerequisites:
#   - Azure CLI installed and logged in (az login)
#   - Sufficient permissions to create app registrations and assign roles

set -euo pipefail

APP_DISPLAY_NAME="${1:-github-bicep-labs}"

echo "==> Creating app registration: ${APP_DISPLAY_NAME}"
APP_ID=$(az ad app create --display-name "${APP_DISPLAY_NAME}" --query appId -o tsv)
echo "    App (client) ID: ${APP_ID}"

echo "==> Creating service principal"
SP_OBJECT_ID=$(az ad sp create --id "${APP_ID}" --query id -o tsv)
echo "    Service principal object ID: ${SP_OBJECT_ID}"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "==> Subscription: ${SUBSCRIPTION_ID}"
echo "    Tenant:       ${TENANT_ID}"

echo "==> Assigning 'Contributor' role on subscription"
az role assignment create \
  --assignee-object-id "${SP_OBJECT_ID}" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}" \
  --output none

echo "==> Assigning 'User Access Administrator' role on subscription"
az role assignment create \
  --assignee-object-id "${SP_OBJECT_ID}" \
  --assignee-principal-type ServicePrincipal \
  --role "User Access Administrator" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}" \
  --output none

echo ""
echo "============================================"
echo " App Registration created successfully"
echo "============================================"
echo ""
echo " Add these as GitHub repository secrets:"
echo ""
echo "   AZURE_CLIENT_ID       = ${APP_ID}"
echo "   AZURE_TENANT_ID       = ${TENANT_ID}"
echo "   AZURE_SUBSCRIPTION_ID = ${SUBSCRIPTION_ID}"
echo ""
echo " Next step: run create-federated-credentials.sh"
echo "   ./create-federated-credentials.sh <OWNER/REPO> ${APP_ID}"
echo ""
