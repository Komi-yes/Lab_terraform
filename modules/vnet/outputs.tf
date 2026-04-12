output "vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "subnet_web_id" {
  value = azurerm_subnet.web.id
}

output "subnet_bastion_id" {
  value = azurerm_subnet.bastion.id
}