#!/bin/bash
# Fixed State Migration Script for CS Environment
# This migrates ALL resources from module.X.* to module.X[0].*

set -e  # Exit on error

echo "==========================================="
echo "CS State Migration Script (Fixed Version)"
echo "==========================================="
echo ""
echo "This script will migrate ALL CS resources from:"
echo "  module.xxx.* → module.xxx[0].*"
echo ""
echo "⚠️  IMPORTANT: Make sure you have:"
echo "  1. Backed up your state file"
echo "  2. Run 'terraform init' first"
echo "  3. Set enable_hub=true, enable_*_vms=true in cs.tfvars"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

echo ""
echo "Getting list of resources to migrate..."
echo ""

# Get all resources that need migration
# Match resources like: module.web_resources.something (needs migration)
# Skip resources like: module.web_resources[0].something (already migrated)
# Pattern: After module name, look for DOT (not [0])
RESOURCES=$(terraform state list | grep -E "^module\.(hub_infrastructure|sftp|web_resources|app_resources|db_resources_02|db_key_vault|ado_resources)\.[^[]" || true)

if [ -z "$RESOURCES" ]; then
  echo "✅ No resources found that need migration!"
  echo "All resources are already at the correct paths with [0] indexing."
  exit 0
fi

echo "Found $(echo "$RESOURCES" | wc -l) resources to migrate:"
echo "$RESOURCES" | head -20
if [ $(echo "$RESOURCES" | wc -l) -gt 20 ]; then
  echo "... and $(( $(echo "$RESOURCES" | wc -l) - 20 )) more"
fi
echo ""

read -p "Proceed with migration? (yes/no): " confirm2
if [ "$confirm2" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

echo ""
echo "Starting migration..."
echo ""

# Counter for progress
count=0
total=$(echo "$RESOURCES" | wc -l)

# Migrate each resource
while IFS= read -r resource; do
  count=$((count + 1))

  # Extract module name (hub_infrastructure, sftp, web_resources, etc.)
  module_name=$(echo "$resource" | sed -E 's/^module\.([^.]+)\..*/\1/')

  # Create new path with [0]
  new_resource=$(echo "$resource" | sed -E "s/^module\.${module_name}\./module.${module_name}[0]./")

  echo "[$count/$total] Migrating: $resource"
  echo "           to: $new_resource"

  terraform state mv "$resource" "$new_resource"

  if [ $? -ne 0 ]; then
    echo "❌ Migration failed for $resource"
    echo "You may need to fix this manually."
    read -p "Continue with remaining resources? (yes/no): " continue_prompt
    if [ "$continue_prompt" != "yes" ]; then
      exit 1
    fi
  fi

  echo ""
done <<< "$RESOURCES"

echo ""
echo "==========================================="
echo "✅ Migration Complete!"
echo "==========================================="
echo ""
echo "Next steps:"
echo "1. Run: terraform plan -var-file='environments/em_bofa/cs.tfvars'"
echo "2. Verify: Should show 0 to add, 0 to change, 0 to destroy"
echo "3. If all good, CS environment is migrated!"
echo ""
