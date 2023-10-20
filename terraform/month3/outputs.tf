output vm_name {
    value = azurerm_windows_virtual_machine.windows_vm.name
}

output vm_ip {
    value = azurerm_windows_virtual_machine.windows_vm.private_ip_address
}

output rg_name {
    value = azurerm_resource_group.rg.name
}

output vnet_id {
    value = azurerm_virtual_network.vnet.id
}

output subnet_id {
    value = azurerm_subnet.subnet.id
}
