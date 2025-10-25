#!/bin/bash

# Terraform Import Script for Existing Azure Resources
# This script imports existing Azure resources into Terraform state
# Usage: ./import_resources.sh [environment]
# Example: ./import_resources.sh cs

set -e

echo "=== Terraform Import Script ==="
echo "This script will import existing Azure resources into Terraform state"
echo "Usage: $0 [environment] (default: cs)"
echo ""

# Function to safely import resources
import_resource() {
  local resource_address="$1"
  local resource_id="$2"
  local resource_name="$3"
  local environment="${4:-cs}"
  
  echo "Importing ${resource_name}..."
  if terraform import -var-file="environments/${environment}.tfvars" "${resource_address}" "${resource_id}"; then
    echo "✓ Successfully imported ${resource_name}"
  else
    exit_code=$?
    if [ $exit_code -eq 1 ]; then
      echo "⚠ Resource ${resource_name} already exists in state or import failed"
    else
      echo "✗ Failed to import ${resource_name} with exit code ${exit_code}"
    fi
  fi
  echo ""
}

# Change to terraform directory
cd "$(dirname "$0")/../terraform" || {
  echo "Error: Could not change to terraform directory"
  exit 1
}

echo "Current directory: $(pwd)"
echo ""

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
  echo "Terraform not initialized. Please run 'terraform init' first."
  exit 1
fi

# Check if tfvars file exists
ENVIRONMENT="${1:-cs}"
TFVARS_FILE="environments/${ENVIRONMENT}.tfvars"

if [ ! -f "$TFVARS_FILE" ]; then
  echo "Error: tfvars file '$TFVARS_FILE' not found."
  echo "Available tfvars files:"
  ls -la environments/*.tfvars 2>/dev/null || echo "No tfvars files found in environments/ directory"
  exit 1
fi

echo "Using tfvars file: $TFVARS_FILE"

echo "Starting import of existing Azure resources..."
echo ""

# Import subnet NAT gateway association
import_resource \
  'module.spoke_vnet.module.nat_gateway[0].azurerm_subnet_nat_gateway_association.subnet_association["4"]' \
  "/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-SPOKE/providers/Microsoft.Network/virtualNetworks/US1-BOFA-CS-SPOKE-VNET/subnets/US1-BOFA-CS-SPOKE-ADO-SUBNET" \
  "NAT Gateway Association" \
  "$ENVIRONMENT"

# Import VNet peering: local to aadds
import_resource \
  'module.spoke_vnet.module.vnet_peering[0].azurerm_virtual_network_peering.local_to_aadds' \
  "/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-CS-SPOKE/providers/Microsoft.Network/virtualNetworks/US1-BOFA-CS-SPOKE-VNET/virtualNetworkPeerings/US1-BOFA-CS-SPOKE-VNET-to-US1-BOFA-P-DS-VNET" \
  "VNet Peering (Local to AADDS)" \
  "$ENVIRONMENT"

# Import VNet peering: aadds to local
import_resource \
  'module.spoke_vnet.module.vnet_peering[0].azurerm_virtual_network_peering.aadds_to_local' \
  "/subscriptions/8590c10d-ae02-49ca-a8bb-435f047c71e9/resourceGroups/US1-BOFA-P-DS/providers/Microsoft.Network/virtualNetworks/US1-BOFA-P-DS-VNET/virtualNetworkPeerings/US1-BOFA-P-DS-VNET-to-US1-BOFA-CS-SPOKE-VNET" \
  "VNet Peering (AADDS to Local)" \
  "$ENVIRONMENT"

echo "=== Import process completed ==="
echo "You can now run 'terraform plan' to verify the imported resources."