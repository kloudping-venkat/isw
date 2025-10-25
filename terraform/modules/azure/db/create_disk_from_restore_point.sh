#!/bin/bash
# Script to create managed disk from disk restore point using Azure CLI
# This is a workaround for Terraform azurerm provider not supporting disk restore points directly

set -e

DISK_NAME="$1"
RESOURCE_GROUP="$2"
LOCATION="$3"
RESTORE_POINT_ID="$4"
STORAGE_TYPE="$5"
OS_TYPE="${6:-}"  # Optional: "Linux" or "Windows"

echo "Creating managed disk from restore point..."
echo "Disk Name: $DISK_NAME"
echo "Resource Group: $RESOURCE_GROUP"
echo "Restore Point: $RESTORE_POINT_ID"

# Build the Azure CLI command
CMD="az disk create --name \"$DISK_NAME\" --resource-group \"$RESOURCE_GROUP\" --location \"$LOCATION\" --sku \"$STORAGE_TYPE\" --source \"$RESTORE_POINT_ID\""

if [ -n "$OS_TYPE" ]; then
  CMD="$CMD --os-type \"$OS_TYPE\""
fi

# Execute the command
eval $CMD

echo "Managed disk created successfully: $DISK_NAME"
