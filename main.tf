provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "test" {
  name     = "acctestRG-dsc-test19"
  location = "eastus2"
}

resource "azurerm_automation_account" "test" {
  name                                = "acctest-dsc-test10"
  location                           = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
  sku_name                        = "Basic"
}

resource "azurerm_automation_dsc_configuration" "test" {
  name                                         = "TestConfig"
  resource_group_name           = azurerm_resource_group.test.name
  automation_account_name = azurerm_automation_account.test.name
  location                                     = azurerm_resource_group.test.location
  description                               = "testing"
  content_embedded = <<CONTENT
    configuration TestConfig
                                {
                                                Node IsWebServer
                                                {
                                                                WindowsFeature IIS
                                                                {
                                                                                Ensure               = 'Present'
                                                                                Name                 = 'Web-Server'
                                                                                IncludeAllSubFeature = $true
                                                                }
                                                }

                                                Node NotWebServer
                                                {
                                                                WindowsFeature IIS
                                                                {
                                                                                Ensure               = 'Absent'
                                                                                Name                 = 'Web-Server'
                                                                }
                                                }
                                }
  CONTENT
  
  lifecycle {
    ignore_changes = [content_embedded]
  }
}

resource "azurerm_virtual_network" "test" {
  name                              = "acctvn-test10"
  address_space              = ["10.0.0.0/16"]
  location                          = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
}

resource "azurerm_subnet" "test" {
  name                                 = "acctsub-test10"
  resource_group_name  = azurerm_resource_group.test.name
  virtual_network_name = azurerm_virtual_network.test.name
  address_prefixes           = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "test" {
  name                               = "acctni-test10"
  location                          = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name

  ip_configuration {
    name                                            = "testconfiguration1"
    subnet_id                                    = azurerm_subnet.test.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_storage_account" "test" {
  name                                    = "accsatest10"
  resource_group_name      = azurerm_resource_group.test.name
  location                                = azurerm_resource_group.test.location
  account_tier                        = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "staging"
  }
}

resource "azurerm_storage_container" "test" {
  name                                  = "vhds"
  storage_account_name  = azurerm_storage_account.test.name
  container_access_type   = "private"
}

resource "azurerm_virtual_machine" "test" {
  name                               = "acctvmtest10"
  location                           = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
  network_interface_ids = [azurerm_network_interface.test.id]
  vm_size                           = "Standard_F2"

  storage_image_reference {
      publisher = "Canonical"
      offer     = "UbuntuServer"
      sku       = "16.04-LTS"
      version   = "latest"
  }

  storage_os_disk {
      name          = "myosdisk1"
      vhd_uri       = "${azurerm_storage_account.test.primary_blob_endpoint}${azurerm_storage_container.test.name}/myosdisk1.vhd"
      caching       = "ReadWrite"
      create_option = "FromImage"
  }

  os_profile {
      computer_name  = "hostanmetest10"
      admin_username = "testadmni"
      admin_password = "Password1357!"
  }

  os_profile_linux_config {
      disable_password_authentication = false
  }
}

resource "azurerm_virtual_machine_extension" "test" {
  name                             = "DSCForLinux"
  virtual_machine_id     = azurerm_virtual_machine.test.id
  publisher                       = "Microsoft.OSTCExtensions"
  type                                = "DSCForLinux"
  type_handler_version = "2.70"

  settings = <<SETTINGS
                  {
                    "ConfigurationMode": "ApplyAndMonitor",
                    "ConfigurationModeFrequencyMins": "15",
                      "ExtensionAction": "Register",
                      "NodeConfigurationName": "TestConfig.NotWebServer",
                     "RefreshFrequencyMins": "30",                                          
                      "RegistrationUrl": "${azurerm_automation_account.test.dsc_server_endpoint}",
                      "RegistrationKey": "${azurerm_automation_account.test.dsc_primary_access_key}",
                    "RebootNodeIfNeeded": "false",
                    "ActionAfterReboot": "ContinueConfiguration",
                    "AllowModuleOverwrite": "false"
                  }
SETTINGS
}
