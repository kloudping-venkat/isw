terraform {
  backend "azurerm" {
    resource_group_name  = "#{{tf_resource_group_name}}#"
    storage_account_name = "#{{tf_storage_account_name}}#"
    container_name       = "#{{tf_container_name}}#"
    key                  = "#{{tf_state_file}}#"
    use_msi              = true
  }
}
