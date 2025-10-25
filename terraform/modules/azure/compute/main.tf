# EM Compute Module - Windows Server Configuration
# Deploys Windows Server 2022 in Web Subnet

# Generate random password for Windows Server
resource "random_password" "vm_password" {
  length  = 12
  special = true
  upper   = true
  lower   = true
  numeric = true
  # Use only safe special characters for Windows VM login
  # Avoid problematic characters like quotes, backslashes, and complex symbols
  override_special = "!@#$%*-_+"
}

# Store password in Key Vault
resource "azurerm_key_vault_secret" "vm_password" {
  name         = "${var.vm_name}-admin-password"
  value        = random_password.vm_password.result
  key_vault_id = var.key_vault_id

  depends_on = [random_password.vm_password]
}

# Network Interface for Windows Server
resource "azurerm_network_interface" "vm_nic" {
  name                = "${var.vm_name}-NIC"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.enable_public_ip ? azurerm_public_ip.vm_public_ip[0].id : null
  }

  tags = var.tags
}

# Public IP (optional)
resource "azurerm_public_ip" "vm_public_ip" {
  count = var.enable_public_ip ? 1 : 0

  name                = "${var.vm_name}-PUBLIC-IP"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Network Security Group for VM
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "${var.vm_name}-NSG"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow RDP access from VirtualNetwork
  security_rule {
    name                       = "Allow-RDP-VNet"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Allow RDP access from VPN clients
  security_rule {
    name                       = "Allow-RDP-VPN"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "172.16.0.0/24"
    destination_address_prefix = "*"
  }

  # Allow HTTP traffic
  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Allow HTTPS traffic
  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Outbound rules for domain join - DNS (UDP)
  security_rule {
    name                       = "Allow-DNS-UDP-Outbound"
    priority                   = 2001
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Outbound rules for domain join - DNS (TCP)
  security_rule {
    name                       = "Allow-DNS-TCP-Outbound"
    priority                   = 2002
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Outbound rules for domain join - LDAP
  security_rule {
    name                       = "Allow-LDAP-Outbound"
    priority                   = 2003
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Outbound rules for domain join - LDAPS
  security_rule {
    name                       = "Allow-LDAPS-Outbound"
    priority                   = 2004
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "636"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Outbound rules for domain join - Kerberos
  security_rule {
    name                       = "Allow-Kerberos-Outbound"
    priority                   = 2005
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "88"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Outbound rules for domain join - Kerberos UDP
  security_rule {
    name                       = "Allow-Kerberos-UDP-Outbound"
    priority                   = 2006
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "88"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Outbound rules for domain join - SMB/CIFS
  security_rule {
    name                       = "Allow-SMB-Outbound"
    priority                   = 2007
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "445"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Outbound rules for domain join - RPC Endpoint Mapper
  security_rule {
    name                       = "Allow-RPC-Endpoint-Outbound"
    priority                   = 2008
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "135"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Outbound rules for domain join - Dynamic RPC ports
  security_rule {
    name                       = "Allow-RPC-Dynamic-Outbound"
    priority                   = 2009
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "49152-65535"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# Associate NSG with Network Interface
resource "azurerm_network_interface_security_group_association" "vm_nsg_association" {
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

# Windows Virtual Machine
resource "azurerm_windows_virtual_machine" "vm" {
  name                = var.vm_name
  # Computer name: Extract role and VM number from vm_name (e.g., "CS-PROD-WEB-VM01" -> "CS-WEB-VM01")
  # Windows computer name max 15 characters, format: PREFIX-ROLE-VMXX
  computer_name       = substr(upper(replace(
    "${var.environment_code}-${lookup(var.tags, "Role", "") == "WebServer" ? "WEB" : (lookup(var.tags, "Role", "") == "ADOAgent" ? "ADO" : "APP")}-${reverse(split("-", var.vm_name))[0]}",
    "_", ""
  )), 0, 15)
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.vm_password.result
  patch_mode          = "AutomaticByPlatform"

  # Prevent VM recreation when computer_name changes
  # This allows updating the formula without destroying existing VMs
  lifecycle {
    ignore_changes = [computer_name]
  }

  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = var.windows_sku
    version   = "latest"
  }

  # Enable boot diagnostics
  boot_diagnostics {
    storage_account_uri = var.storage_account_uri
  }

  # Enable system-assigned managed identity for storage access
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  depends_on = [
    azurerm_network_interface_security_group_association.vm_nsg_association
  ]
}

# Data Disks
resource "azurerm_managed_disk" "data_disks" {
  count = length(var.data_disks)

  name                 = "${var.vm_name}-DataDisk-${count.index + 1}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.data_disks[count.index].size_gb

  tags = var.tags
}

# Attach Data Disks to VM
resource "azurerm_virtual_machine_data_disk_attachment" "data_disk_attachments" {
  count = length(var.data_disks)

  managed_disk_id    = azurerm_managed_disk.data_disks[count.index].id
  virtual_machine_id = azurerm_windows_virtual_machine.vm.id
  lun                = var.data_disks[count.index].lun
  caching            = "ReadWrite"

  depends_on = [azurerm_windows_virtual_machine.vm]
}

# Comprehensive BOFA VM Configuration Extension
resource "azurerm_virtual_machine_extension" "bofa_vm_configuration" {
  count                = var.enable_vm_extensions ? 1 : 0
  name                 = "${var.vm_name}-BOFA-Configuration-Extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  # Add auto upgrade to handle any extension updates
  auto_upgrade_minor_version = true

  # Protected settings for sensitive parameters (PAT token and service account password)
  protected_settings = jsonencode({
    "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File configure-vm.ps1 -AdoPat ${var.ado_pat_token} -AdoOrgUrl ${var.ado_organization_url} -AdoDeploymentPool ${var.ado_deployment_pool} -AdoAgentName ${var.vm_name} -AdoServiceUser ${var.ado_service_user}${var.ado_service_password != "" ? " -AdoServicePassword ${var.ado_service_password}" : ""} -ExpectedDiskCount ${length(var.data_disks)} -VmRole ${lookup(var.tags, "Role", "")} -AdminUsername ${var.admin_username}${var.app_service_account != null ? " -AppServiceAccount ${var.app_service_account}" : ""}"
  })

  # Reference the script from shared public blob storage
  # Add file hash to force cache refresh when scripts are updated
  # This will only change when the actual script content changes
  settings = jsonencode({
    "fileUris" = [
      "${var.scripts_blob_endpoint}${var.scripts_container_name}/configure-vm.ps1",
      "${var.scripts_blob_endpoint}${var.scripts_container_name}/SentinelOne_install.ps1",
      "${var.scripts_blob_endpoint}${var.scripts_container_name}/Tanium_install_script.ps1",
      "${var.scripts_blob_endpoint}${var.scripts_container_name}/Oracle_client_install.ps1",
      "${var.scripts_blob_endpoint}${var.scripts_container_name}/gMSA_configuration.ps1",
      "${var.scripts_blob_endpoint}${var.scripts_container_name}/Datadog_GPG_install.ps1"
    ]
    "scriptHash" = filemd5("${path.module}/scripts/configure-vm.ps1")
  })

  tags = var.tags

  depends_on = [
    azurerm_windows_virtual_machine.vm,
    azurerm_virtual_machine_data_disk_attachment.data_disk_attachments
  ]
}