# Create a key vault
resource "azurerm_key_vault" "keyvault" {
  name                          = "keyvault-${var.owner}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  rbac_authorization_enabled    = false
  enabled_for_disk_encryption   = true
  tenant_id                     = var.tenant_id
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  public_network_access_enabled = true
  tags                          = var.tags

  sku_name = "standard"

  # Access for the current user (to manage the key vault)
  access_policy {
    tenant_id = var.tenant_id
    object_id = var.object_id

    key_permissions     = ["Get", "List", "Create", "Delete"]
    secret_permissions  = ["Get", "List", "Set", "Delete"]
    storage_permissions = ["Get", "List"]
  }

  # Access for AKS (the kubelet that will retrieve secrets at runtime)
  access_policy {
    tenant_id = var.tenant_id
    object_id = var.aks_object_id

    secret_permissions = ["Get"]
  }

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [var.subnet_id]
  }
}

# Grant the current user access to the key vault
resource "azurerm_key_vault_access_policy" "keyvault_access_policy" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = var.tenant_id
  object_id    = var.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Recover",
    "Purge"
  ]
}

resource "time_sleep" "wait_for_access_policy" {
  depends_on      = [azurerm_key_vault.keyvault]
  create_duration = "60s"
}

# Stock API key in key vault
resource "random_password" "backend_api_key" {
  length  = 32
  special = false
}

resource "azurerm_key_vault_secret" "backend-api-key" {
  name         = "backend-api-key"
  value        = random_password.backend_api_key.result
  key_vault_id = azurerm_key_vault.keyvault.id
  depends_on   = [time_sleep.wait_for_access_policy, azurerm_key_vault_access_policy.keyvault_access_policy]
}