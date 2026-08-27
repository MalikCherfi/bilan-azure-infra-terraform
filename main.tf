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

provider "helm" {
  kubernetes = {
    host                   = data.azurerm_kubernetes_cluster.shared.kube_admin_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.shared.kube_admin_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.shared.kube_admin_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.shared.kube_admin_config.0.cluster_ca_certificate)
  }
}

# Create a namespace for ingress-nginx
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  set = [{
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }]
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

resource "time_sleep" "wait_for_access_policy" {
  depends_on      = [azurerm_key_vault.keyvault]
  create_duration = "60s"
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
  name                   = "psqlflexibleservermcherfi"
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = "16"
  administrator_login    = "malikcherfi"
  administrator_password = random_password.psql_admin.result
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"
  tags                   = local.tags
  zone                   = "1"
}

# Create a key vault secret
resource "azurerm_key_vault_secret" "psql_password" {
  name         = "psql-admin-password"
  value        = random_password.psql_admin.result
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [time_sleep.wait_for_access_policy]
}

# Create a postgresql database
resource "azurerm_postgresql_flexible_server_database" "psql_database" {
  name      = "psql_database"
  server_id = azurerm_postgresql_flexible_server.psql_flexible_server.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

# Autoriser les services Azure (dont le cluster AKS) à contacter PostgreSQL
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.psql_flexible_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# (Optionnel mais recommandé) Stocker le FQDN de la base dans Key Vault
resource "azurerm_key_vault_secret" "psql_host" {
  name         = "psql-host"
  value        = azurerm_postgresql_flexible_server.psql_flexible_server.fqdn
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [time_sleep.wait_for_access_policy]
}

# Create a redis cache
resource "azurerm_managed_redis" "redis" {
  name                = "redismcherfi"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_name            = "Balanced_B0"
  tags                = local.tags

  default_database {
    access_keys_authentication_enabled = true
    clustering_policy                  = "OSSCluster"
    eviction_policy                    = "VolatileLRU"
  }

}

# Storage Account Azure
resource "azurerm_storage_account" "sa" {
  name                     = "stbilanappmcherfi"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Container Blob par défaut (optionnel mais recommandé)
resource "azurerm_storage_container" "container" {
  name                  = "uploads"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}

# Génération automatique du token SAS
data "azurerm_storage_account_sas" "sas" {
  connection_string = azurerm_storage_account.sa.primary_connection_string
  https_only        = true

  resource_types {
    service   = true
    container = true
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  permissions {
    read    = true
    write   = true
    delete  = true
    list    = true
    add     = true
    create  = true
    update  = true
    process = false
    tag     = false
    filter  = false
  }

  start  = "2026-01-01T00:00:00Z"
  expiry = "2028-01-01T00:00:00Z"
}

# Stockage des secrets dans Key Vault
resource "azurerm_key_vault_secret" "storage_name" {
  name         = "storage-account-name"
  value        = azurerm_storage_account.sa.name
  key_vault_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_key_vault_secret" "storage_sas" {
  name         = "storage-sas-token"
  value        = data.azurerm_storage_account_sas.sas.sas
  key_vault_id = azurerm_key_vault.keyvault.id
}

output "redis_primary_access_key" {
  value     = azurerm_managed_redis.redis.default_database[0].primary_access_key
  sensitive = true
}

resource "azurerm_key_vault_secret" "redis_password" {
  name         = "redis-password"
  value        = azurerm_managed_redis.redis.default_database[0].primary_access_key
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [time_sleep.wait_for_access_policy]
}

resource "azurerm_key_vault_secret" "redis_hostname" {
  name         = "redis-hostname"
  value        = azurerm_managed_redis.redis.hostname
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [time_sleep.wait_for_access_policy]
}

resource "random_password" "backend_api_key" {
  length  = 32
  special = false
}

resource "azurerm_key_vault_secret" "backend-api-key" {
  name         = "backend-api-key"
  value        = random_password.backend_api_key.result
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [time_sleep.wait_for_access_policy]
}

