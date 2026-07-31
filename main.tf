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

# Create a key vault
resource "azurerm_key_vault" "keyvault" {
  name                        = "keyvault"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  rbac_authorization_enabled  = false
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  tags                        = local.tags

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_kubernetes_cluster.shared.kubelet_identity[0].object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
    ]

    storage_permissions = [
      "Get",
    ]
  }
}

# Create a azure container registry
resource "azurerm_container_registry" "acr" {
  name                = "acr"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  tags                = local.tags
}



# Assign ACR pull role
resource "azurerm_role_assignment" "acr_pull" {
  principal_id         = data.azurerm_kubernetes_cluster.shared.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}

resource "random_password" "psql_admin" {
  length  = 24
  special = true
}

# Create a postgresql flexible server
resource "azurerm_postgresql_flexible_server" "psql_flexible_server" {
  name                   = "psqlflexibleserver"
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = "16"
  administrator_login    = "malikcherfi"
  administrator_password = random_password.psql_admin.result
  storage_mb             = 32768
  sku_name               = "GP_Standard_D4s_v3"
  tags                   = local.tags
}

# Create a key vault secret
resource "azurerm_key_vault_secret" "psql_password" {
  name         = "psql-admin-password"
  value        = random_password.psql_admin.result
  key_vault_id = azurerm_key_vault.keyvault.id
}

# Create a postgresql database
resource "azurerm_postgresql_flexible_server_database" "psql_database" {
  name      = "psql_database"
  server_id = azurerm_postgresql_flexible_server.psql_flexible_server.id
  collation = "en_US.utf8"
  charset   = "UTF8"

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = true
  }
}

# Create a redis cache
resource "azurerm_managed_redis" "redis" {
  name                = "redis"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_name            = "Balanced_B3"
  tags                = local.tags

}



