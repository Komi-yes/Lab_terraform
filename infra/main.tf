# Resource Group y wiring de módulos
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
  tags     = var.tags
}

module "vnet" {
  source              = "../modules/vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  prefix              = var.prefix
  tags                = var.tags
}

module "compute" {
  source              = "../modules/compute"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  prefix              = var.prefix
  admin_username      = var.admin_username
  ssh_public_key      = file(pathexpand(var.ssh_public_key))
  subnet_id           = module.vnet.subnet_web_id
  vm_count            = var.vm_count
  cloud_init          = file("${path.module}/cloud-init.yaml")
  tags                = var.tags
}

module "lb" {
  source              = "../modules/lb"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  prefix              = var.prefix
  backend_nic_ids     = module.compute.nic_ids

  # IMPORTANTE:
  # Si vas a usar Bastion para SSH y NO quieres acceso SSH directo desde Internet,
  # cambia en dev.tfvars allow_ssh_from_cidr por 10.10.3.0/26
  allow_ssh_from_cidr = var.allow_ssh_from_cidr

  tags = var.tags
}

# RETO 1: Azure Bastion
# -------------------------------------------------------------------

resource "azurerm_public_ip" "bastion_pip" {
  name                = "${var.prefix}-bastion-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "bastion" {
  name                = "${var.prefix}-bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Basic"
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = module.vnet.subnet_bastion_id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }
}

# RETO 2: Azure Monitor alert para estado del health probe del LB
# -------------------------------------------------------------------

resource "azurerm_monitor_action_group" "alerts" {
  name                = "${var.prefix}-alerts"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "lab8ag"

  email_receiver {
    name                    = "student-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_metric_alert" "lb_probe_status" {
  name                = "${var.prefix}-lb-probe-alert"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [module.lb.lb_id]
  description         = "Alerta cuando el Health Probe Status del Load Balancer baja de 100%"
  severity            = 2
  enabled             = true
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Network/loadBalancers"
    metric_name      = "DipAvailability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 100
  }

  action {
    action_group_id = azurerm_monitor_action_group.alerts.id
  }
}