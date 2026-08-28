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
  tags                   = var.tags
  zone                   = "1"
}

# Create a postgresql database
resource "azurerm_postgresql_flexible_server_database" "psql_database" {
  name      = "psql_database"
  server_id = azurerm_postgresql_flexible_server.psql_flexible_server.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

# Autorize cluster access
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.psql_flexible_server.id
  start_ip_address = "4.211.70.39" # Update if cluster is redeployed
  end_ip_address   = "4.211.70.39" # Update if cluster is redeployed
}



# Stock FQDN in key vault
resource "azurerm_key_vault_secret" "psql_host" {
  name         = "psql-host"
  value        = azurerm_postgresql_flexible_server.psql_flexible_server.fqdn
  key_vault_id = var.keyvault_id
  depends_on   = [var.wait_for_access_policy, var.keyvault_access_policy]
}

# Stock admin password in key vault
resource "azurerm_key_vault_secret" "psql_password" {
  name         = "psql-admin-password"
  value        = random_password.psql_admin.result
  key_vault_id = var.keyvault_id
  depends_on   = [var.wait_for_access_policy, var.keyvault_access_policy]
}
