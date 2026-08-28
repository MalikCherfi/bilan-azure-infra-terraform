locals {
  tags = merge(
    {
      managed_by  = "terraform"
      environment = "bilan-tp"
      owner       = var.owner
    },
    var.tags
  )
}



# Get current subscription
data "azurerm_client_config" "current" {}

# Get AKS cluster
data "azurerm_kubernetes_cluster" "shared" {
  name                = "aks-nonprod-prf2026"
  resource_group_name = "rg-shared-prf2026"
}

data "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  virtual_network_name = "aks-vnet-15722120" # Update with new VNet name if cluster is recreated
  resource_group_name  = data.azurerm_kubernetes_cluster.shared.node_resource_group
}
provider "helm" {
  kubernetes = {
    host                   = data.azurerm_kubernetes_cluster.shared.kube_admin_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.shared.kube_admin_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.shared.kube_admin_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.shared.kube_admin_config.0.cluster_ca_certificate)
  }
}

module "ingress-nginx" {
  source = "./modules/ingress-nginx"
}

module "keyvault" {
  source = "./modules/keyvault"

  resource_group_name = var.resource_group_name
  location            = var.location
  owner               = var.owner
  tags                = local.tags
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = data.azurerm_kubernetes_cluster.shared.kubelet_identity[0].object_id
  aks_object_id       = data.azurerm_kubernetes_cluster.shared.kubelet_identity[0].object_id
  subnet_id           = data.azurerm_subnet.aks_subnet.id
}

module "container-registry" {
  source = "./modules/container-registry"

  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.tags
  aks_object_id       = data.azurerm_kubernetes_cluster.shared.kubelet_identity[0].object_id
}

module "psql" {
  source = "./modules/postgresql"

  resource_group_name    = var.resource_group_name
  location               = var.location
  tags                   = local.tags
  keyvault_id            = module.keyvault.keyvault_id
  wait_for_access_policy = module.keyvault.wait_for_access_policy
  keyvault_access_policy = module.keyvault.keyvault_access_policy
}

module "redis" {
  source = "./modules/redis"

  resource_group_name    = var.resource_group_name
  location               = var.location
  tags                   = local.tags
  keyvault_id            = module.keyvault.keyvault_id
  wait_for_access_policy = module.keyvault.wait_for_access_policy
  keyvault_access_policy = module.keyvault.keyvault_access_policy
}

module "storage-account" {
  source = "./modules/storage-account"

  resource_group_name    = var.resource_group_name
  location               = var.location
  tags                   = local.tags
  subnet_id              = data.azurerm_subnet.aks_subnet.id
  keyvault_id            = module.keyvault.keyvault_id
  keyvault_access_policy = module.keyvault.keyvault_access_policy
}

