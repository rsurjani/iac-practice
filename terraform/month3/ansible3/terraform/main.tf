resource "azurerm_resource_group" "rg" {
  location = "eastus"
  name     = "ansible-month3-rg"
}
 
# Create virtual network
resource "azurerm_virtual_network" "my_terraform_network" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
 
# Create subnet
resource "azurerm_subnet" "my_terraform_subnet" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}
 
# Create Windows VM public IP
resource "azurerm_public_ip" "my_windows_public_ip" {
  name                = "myWindowsPublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
  domain_name_label   = "vm-${random_id.random_id.hex}"
}
 
# Create Network Security Group and rule
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "myNetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
 
  security_rule {
    name                       = "AllowAnyHTTPInbound"
    priority                   = 1012
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
 
    security_rule {
    name                       = "AllowAnyWinRMInbound"
    priority                   = 1022
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5985-5986"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
 
# Connect the security group to the subnet
resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.my_terraform_subnet.id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}
 
# Generate random text for a unique names
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }
 
  byte_length = 8
}
 
resource "azurerm_windows_virtual_machine" "windows_vm" {
  name                = "MyWindowsVM"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2ms"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.vm_nic.id
  ]
 
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
 
  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
 
  winrm_listener {
      protocol = "Https"
      certificate_url = azurerm_key_vault_certificate.certificate.secret_id
  }
 
  secret {
    certificate {
        store = "My"
        url   = azurerm_key_vault_certificate.certificate.secret_id
      }
      key_vault_id = azurerm_key_vault.keyvault.id
    }
}
 
resource "azurerm_network_interface" "vm_nic" {
  name                = "MyWindowsVM-nic"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
 
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_windows_public_ip.id
  }
}
 
resource "azurerm_dev_test_global_vm_shutdown_schedule" "rg" {
  virtual_machine_id = azurerm_windows_virtual_machine.windows_vm.id
  location           = azurerm_resource_group.rg.location
  enabled            = true
 
  daily_recurrence_time = "2300"
  timezone              = "Eastern Standard Time"
 
 
  notification_settings {
    enabled         = false
 
  }
 }
 
########################
# Key vault/cert stuff #
########################
data "azurerm_client_config" "current" {}
 
resource "azurerm_key_vault" "keyvault" {
  name                       = "vault-${random_id.random_id.hex}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 7
  enabled_for_deployment     = true
 
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
 
    certificate_permissions = [
      "Create",
      "Get",
      "List"
    ]
  }
}
 
resource "azurerm_key_vault_certificate" "certificate" {
  name         = "generated-cert"
  key_vault_id = azurerm_key_vault.keyvault.id
 
  certificate_policy {
    issuer_parameters {
      name = "Self"
    }
 
    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }
 
    secret_properties {
      content_type = "application/x-pkcs12"
    }
 
    x509_certificate_properties {
      # Server Authentication = 1.3.6.1.5.5.7.3.1
      # Client Authentication = 1.3.6.1.5.5.7.3.2
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]
 
      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]
 
      subject            = "CN=${azurerm_public_ip.my_windows_public_ip.fqdn}"
      validity_in_months = 12
    }
  }
}
 
resource "local_file" "hosts_ini" {
  filename = "../hosts.ini"
  content  = <<-EOT
  [all]
  ${azurerm_public_ip.my_windows_public_ip.fqdn}
 
  [all:vars]
  ansible_user=${azurerm_windows_virtual_machine.windows_vm.admin_username}
  ansible_password=${azurerm_windows_virtual_machine.windows_vm.admin_password}
  ansible_connection=winrm
  ansible_winrm_transport=ntlm
  ansible_winrm_server_cert_validation=ignore
  EOT
}
