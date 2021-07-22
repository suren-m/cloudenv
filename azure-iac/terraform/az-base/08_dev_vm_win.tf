resource "azurerm_network_interface" "nic_win" {
  name = "${local.res_prefix}-win"

  location            = var.loc.long
  resource_group_name = azurerm_resource_group.base.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "win_dev" {
  name                = "${local.res_prefix}-win"
  resource_group_name = azurerm_resource_group.base.name
  location            = azurerm_resource_group.base.location
  size                = "Standard_D2as_v4"
  admin_username      = var.winuser
  admin_password      = var.winpass
  network_interface_ids = [
    azurerm_network_interface.nic_win.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = "127"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "21h1-pro"
    version   = "latest"
  }
}