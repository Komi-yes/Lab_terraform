output "lb_public_ip" {
  value = module.lb.public_ip
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "vm_names" {
  value = module.compute.vm_names
}

output "bastion_name" {
  value = azurerm_bastion_host.bastion.name
}

output "bastion_public_ip" {
  value = azurerm_public_ip.bastion_pip.ip_address
}

output "lb_probe_alert_name" {
  value = azurerm_monitor_metric_alert.lb_probe_status.name
}