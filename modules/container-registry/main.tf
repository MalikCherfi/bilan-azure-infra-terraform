# Create a azure container registry
resource "azurerm_container_registry" "acr" {
  name                = "containerregistrymcherfi"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  tags                = var.tags
}

# Assign ACR pull role
resource "azurerm_role_assignment" "acr_pull" {
  principal_id         = var.aks_object_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}