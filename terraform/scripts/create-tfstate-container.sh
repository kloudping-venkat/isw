#!/bin/bash
# Create tfstate container for non-CS environments
# Run this once to set up the container for Walmart and future environments

STORAGE_ACCOUNT="stcertentterraform47486"
RESOURCE_GROUP="rg-terraform-state"
CONTAINER_NAME="tfstate"

echo "=========================================="
echo "Creating tfstate Container"
echo "=========================================="
echo ""
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Resource Group: $RESOURCE_GROUP"
echo "Container: $CONTAINER_NAME"
echo ""

# Create the container
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --auth-mode login

if [ $? -eq 0 ]; then
  echo ""
  echo "=========================================="
  echo "✅ Container Created Successfully!"
  echo "=========================================="
  echo ""
  echo "Container: $CONTAINER_NAME"
  echo "Storage Account: $STORAGE_ACCOUNT"
  echo ""
  echo "You can now run Walmart pipeline!"
  echo "State file will be: em_bofa-walmart.tfstate"
  echo ""
else
  echo ""
  echo "=========================================="
  echo "❌ Failed to Create Container"
  echo "=========================================="
  echo ""
  echo "Check:"
  echo "1. You're logged in to Azure: az login"
  echo "2. You have permissions on storage account"
  echo "3. Container doesn't already exist"
  echo ""
  exit 1
fi
