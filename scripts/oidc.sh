#!/usr/bin/env bash
set -euo pipefail

RG="mcherfiRG"
LOCATION="francecentral"
IDENTITY_NAME="github-mi-malikcherfi"
GITHUB_ORG="MalikCherfi"
GITHUB_REPO="bilan-azure-infra-terraform"
BRANCH="main"

az identity create \
  --name "$IDENTITY_NAME" \
  --resource-group "$RG" \
  --location "$LOCATION"

CLIENT_ID=$(az identity show --name "$IDENTITY_NAME" --resource-group "$RG" --query clientId -o tsv)
SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

az identity federated-credential create \
  --name "github-${GITHUB_REPO}-${BRANCH}" \
  --identity-name "$IDENTITY_NAME" \
  --resource-group "$RG" \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/${BRANCH}" \
  --audiences "api://AzureADTokenExchange"

echo "AZURE_CLIENT_ID=$CLIENT_ID"
echo "AZURE_TENANT_ID=$TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID=$SUB_ID"