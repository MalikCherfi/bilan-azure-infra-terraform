#!/bin/bash
set -euo pipefail

RESOURCE_GROUP="mcherfiRG"
STORAGE_ACCOUNT="stcherfiterraform"
CONTAINER_NAME="tfstate"

az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --sku Standard_LRS \
  --encryption-services blob \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

sleep 10

az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login

echo "Backend prêt : $STORAGE_ACCOUNT/$CONTAINER_NAME"