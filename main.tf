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

# Create a azure container registry
resource "azurerm_container_registry" "acr" {
  name                = "container-registry"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  tags                = local.tags
}

# Get AKS cluster
data "azurerm_kubernetes_cluster" "shared" {
  name                = "aks-nonprod-prf2026"
  resource_group_name = "rg-shared-prf2026"
}

# Assign ACR pull role
resource "azurerm_role_assignment" "acr_pull" {
  principal_id         = data.azurerm_kubernetes_cluster.shared.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}
