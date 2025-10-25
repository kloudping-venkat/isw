#!/bin/bash
# Fix Partially Migrated State
# Use this if migration ran but verification failed with "133 to add, 133 to destroy"

set -e  # Exit on error

echo "==========================================="
echo "Fix Partial Migration"
echo "==========================================="
echo ""
echo "This script will complete a partial migration that was interrupted."
echo ""
echo "⚠️  IMPORTANT: Make sure you have:"
echo "  1. Run 'terraform init' first"
echo "  2. Have a state backup available"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

echo ""
echo "Step 1: Checking current state..."
echo ""

# Get resources still needing migration (without [0] on parent module)
echo "Resources still needing migration:"
RESOURCES=$(terraform state list | grep -E "^module\.(hub_infrastructure|sftp|web_resources|app_resources|db_resources_02|db_key_vault|ado_resources)\.[^[]" || true)

if [ -z "$RESOURCES" ]; then
  echo "✅ No resources need migration!"
  echo ""
  echo "All resources are at correct paths. Running verification..."
  terraform plan -var-file="environments/em_bofa/cs.tfvars"
  exit 0
fi

RESOURCE_COUNT=$(echo "$RESOURCES" | wc -l)
echo "Found $RESOURCE_COUNT resources that still need migration:"
echo "$RESOURCES" | head -20
if [ $RESOURCE_COUNT -gt 20 ]; then
  echo "... and $(( $RESOURCE_COUNT - 20 )) more"
fi
echo ""

echo "Step 2: Checking for resources already migrated..."
echo ""

# Get resources already migrated (with [0] on parent module)
MIGRATED=$(terraform state list | grep -E "^module\.(hub_infrastructure|sftp|web_resources|app_resources|db_resources_02|db_key_vault|ado_resources)\[0\]" || true)

if [ -n "$MIGRATED" ]; then
  MIGRATED_COUNT=$(echo "$MIGRATED" | wc -l)
  echo "Found $MIGRATED_COUNT resources already migrated (have [0]):"
  echo "$MIGRATED" | head -10
  if [ $MIGRATED_COUNT -gt 10 ]; then
    echo "... and $(( $MIGRATED_COUNT - 10 )) more"
  fi
  echo ""
fi

echo "Step 3: Migrating remaining resources..."
echo ""

read -p "Proceed with migration of $RESOURCE_COUNT resources? (yes/no): " confirm2
if [ "$confirm2" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

echo ""

# Counter for progress
count=0

# Migrate each resource
while IFS= read -r resource; do
  count=$((count + 1))

  # Extract module name
  module_name=$(echo "$resource" | sed -E 's/^module\.([^.]+)\..*/\1/')

  # Create new path with [0]
  new_resource=$(echo "$resource" | sed -E "s/^module\.${module_name}\./module.${module_name}[0]./")

  echo "[$count/$RESOURCE_COUNT] Migrating:"
  echo "  FROM: $resource"
  echo "  TO:   $new_resource"

  if terraform state mv "$resource" "$new_resource"; then
    echo "  ✅ Success"
  else
    echo "  ❌ FAILED"
    echo ""
    echo "ERROR: Migration failed for $resource"
    echo "You may need to manually migrate this resource or restore from backup."
    exit 1
  fi

  echo ""
done <<< "$RESOURCES"

echo ""
echo "==========================================="
echo "✅ Migration Complete!"
echo "==========================================="
echo "Migrated $count additional resources"
echo ""
echo "Step 4: Running verification..."
echo ""

terraform plan -var-file="environments/em_bofa/cs.tfvars"

echo ""
echo "If plan shows 0 changes, migration is successful!"
echo "If plan still shows changes, there may be other issues."
echo ""
