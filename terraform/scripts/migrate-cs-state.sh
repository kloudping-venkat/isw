#!/bin/bash
# State Migration Script for CS Environment
# Run this ONCE to migrate existing CS resources to new state paths with [0]

echo "========================================="
echo "CS State Migration Script"
echo "========================================="
echo ""
echo "This script will migrate CS resources from:"
echo "  module.xxx → module.xxx[0]"
echo ""
echo "⚠️  IMPORTANT: Make sure you have:"
echo "  1. Backed up your state file"
echo "  2. Set enable_hub=true, enable_*_vms=true in cs.tfvars"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

echo ""
echo "Starting migration..."
echo ""

# Migrate hub_infrastructure
echo "Migrating hub_infrastructure..."
terraform state mv \
  'module.hub_infrastructure' \
  'module.hub_infrastructure[0]'

# Migrate SFTP
echo "Migrating sftp..."
terraform state mv \
  'module.sftp' \
  'module.sftp[0]'

# Migrate web_resources
echo "Migrating web_resources..."
terraform state mv \
  'module.web_resources' \
  'module.web_resources[0]'

# Migrate app_resources
echo "Migrating app_resources..."
terraform state mv \
  'module.app_resources' \
  'module.app_resources[0]'

# Migrate db_resources_02
echo "Migrating db_resources_02..."
terraform state mv \
  'module.db_resources_02' \
  'module.db_resources_02[0]'

# Migrate db_key_vault
echo "Migrating db_key_vault..."
terraform state mv \
  'module.db_key_vault' \
  'module.db_key_vault[0]'

# Migrate ado_resources
echo "Migrating ado_resources..."
terraform state mv \
  'module.ado_resources' \
  'module.ado_resources[0]'

# Migrate random_password
echo "Migrating random_password..."
terraform state mv \
  'random_password.oracle_admin_password_02' \
  'random_password.oracle_admin_password_02[0]'

echo ""
echo "========================================="
echo "✅ Migration Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Run: terraform plan -var-file='environments/em_bofa/cs.tfvars'"
echo "2. Verify: Should show 0 to add, 0 to change, 0 to destroy"
echo "3. If all good, CS environment is migrated!"
echo ""
