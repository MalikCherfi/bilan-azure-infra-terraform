# Create a redis cache
resource "azurerm_managed_redis" "redis" {
  name                = "redismcherfi"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_name            = "Balanced_B0"
  tags                = var.tags

  default_database {
    access_keys_authentication_enabled = true
    clustering_policy                  = "OSSCluster"
    eviction_policy                    = "VolatileLRU"
  }

}

# resource "azurerm_redis_firewall_rule" "aks" {
#   name                = "allowaksegress"
#   redis_cache_name    = azurerm_managed_redis.redis.name
#   resource_group_name = var.resource_group_name
#   start_ip            = "4.211.70.39" # Update if cluster is redeployed
#   end_ip              = "4.211.70.39" # Update if cluster is redeployed
# }

resource "azurerm_key_vault_secret" "redis_password" {
  name         = "redis-password"
  value        = azurerm_managed_redis.redis.default_database[0].primary_access_key
  key_vault_id = var.keyvault_id
  depends_on   = [var.wait_for_access_policy, var.keyvault_access_policy]
}

resource "azurerm_key_vault_secret" "redis_hostname" {
  name         = "redis-hostname"
  value        = azurerm_managed_redis.redis.hostname
  key_vault_id = var.keyvault_id
  depends_on   = [var.wait_for_access_policy, var.keyvault_access_policy]
}