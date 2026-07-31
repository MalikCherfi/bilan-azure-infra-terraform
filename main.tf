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
  name                        = "keyvault-${var.owner}"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  rbac_authorization_enabled  = false
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  tags                        = local.tags

  sku_name = "standard"

  # Accès pour Terraform lui-même (l'identity OIDC qui exécute l'apply)
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions     = ["Get", "List", "Create", "Delete"]
    secret_permissions  = ["Get", "List", "Set", "Delete"]
    storage_permissions = ["Get", "List"]
  }

  # Accès pour AKS (le kubelet qui va récupérer les secrets à l'exécution)
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_kubernetes_cluster.shared.kubelet_identity[0].object_id

    secret_permissions = ["Get"]
  }
}

# Create a azure container registry
resource "azurerm_container_registry" "acr" {
  name                = "containerregistrymcherfi"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  tags                = local.tags
}



# Assign ACR pull role
# resource "azurerm_role_assignment" "acr_pull" {
#   principal_id         = data.azurerm_kubernetes_cluster.shared.kubelet_identity[0].object_id
#   role_definition_name = "AcrPull"
#   scope                = azurerm_container_registry.acr.id
# }

resource "random_password" "psql_admin" {
  length  = 24
  special = true
}

# Create a postgresql flexible server
resource "azurerm_postgresql_flexible_server" "psql_flexible_server" {
  name                   = "psqlflexibleservermcherfi"
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = "16"
  administrator_login    = "malikcherfi"
  administrator_password = random_password.psql_admin.result
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"
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
}

# Create a redis cache
resource "azurerm_managed_redis" "redis" {
  name                = "redismcherfi"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_name            = "Balanced_B0"
  tags                = local.tags

  default_database {
    clustering_policy = "OSSCluster"
    eviction_policy   = "VolatileLRU"
  }

}

resource "azurerm_key_vault_secret" "redis_password" {
  name         = "redis-password"
  value        = azurerm_managed_redis.redis.default_database[0].primary_access_key
  key_vault_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_key_vault_secret" "redis_hostname" {
  name         = "redis-hostname"
  value        = azurerm_managed_redis.redis.hostname
  key_vault_id = azurerm_key_vault.keyvault.id
}



