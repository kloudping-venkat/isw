# ========================================
# SFTP User SSH Keys
# ========================================
# SSH keys for SFTP user authentication
# Add users as needed following the pattern below

# Example SSH Key resource (uncomment and configure when adding users)
# resource "azurerm_ssh_public_key" "sftp_user_example" {
#   name                = "${lower(var.location_code)}${lower(var.client)}${lower(var.environment)}sftp_username"
#   resource_group_name = azurerm_resource_group.environment_rgs["SFTP"].name
#   location            = var.location
#   public_key          = file("~/.ssh/sftp_user_example.pub")
#
#   tags = merge(var.tags, {
#     Purpose = "SFTP-User-SSH-Key"
#     User    = "username"
#   })
# }

# Template for adding new SFTP users:
# 1. Generate SSH key pair: ssh-keygen -t rsa -b 4096 -f ~/.ssh/sftp_username
# 2. Uncomment and configure the resource above
# 3. Update the storage account with local user configuration
# 4. Grant permissions to specific containers

# Storage Account Local Users (SFTP)
# Note: Local users need to be configured after storage account creation
# Use Azure Portal or CLI to add local users and associate SSH keys

# Example Azure CLI commands to add SFTP users:
# az storage account local-user create \
#   --account-name ${module.sftp.storage_account_name} \
#   --resource-group ${azurerm_resource_group.environment_rgs["SFTP"].name} \
#   --name username \
#   --home-directory uploads \
#   --permission-scope permissions=rwdlc service=blob resource-name=uploads \
#   --has-ssh-key true \
#   --ssh-authorized-key key="${azurerm_ssh_public_key.sftp_user_example.public_key}"

# Common SFTP user patterns:
# - bamlimpl: Bank of America ML implementation team
# - B2BiCS: B2B integration CS environment
# Add specific users based on production pattern below:

locals {
  sftp_users = {
    # Uncomment and configure when adding users
    # "bamlimpl" = {
    #   home_directory = "uploads"
    #   ssh_key_file   = "~/.ssh/bamlimpl.pub"
    # }
    # "b2bcs" = {
    #   home_directory = "uploads"
    #   ssh_key_file   = "~/.ssh/b2bcs.pub"
    # }
  }
}

# SSH Public Keys for SFTP users
resource "azurerm_ssh_public_key" "sftp_users" {
  for_each = var.enable_sftp ? local.sftp_users : {}

  name                = "${module.sftp[0].storage_account_name}_${each.key}"
  resource_group_name = azurerm_resource_group.environment_rgs["SFTP"].name
  location            = var.location
  public_key          = file(each.value.ssh_key_file)

  tags = merge(var.tags, {
    Purpose = "SFTP-User-SSH-Key"
    User    = each.key
  })
}

# Note: After creating SSH keys, you must add local users to the storage account
# This can be done via:
# 1. Azure Portal: Storage Account -> SFTP -> Local Users
# 2. Azure CLI (see example commands above)
# 3. Terraform azurerm_storage_account_local_user resource (requires provider version 3.x+)
