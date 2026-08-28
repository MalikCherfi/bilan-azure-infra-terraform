# Create Storage Account Azure
resource "azurerm_storage_account" "sa" {
  name                     = "stbilanappmcherfi"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [var.subnet_id]
  }
}

# Container Blob
resource "azurerm_storage_container" "container" {
  name                  = "uploads"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}

# token SAS generation
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

# Secret storage in keyvault
resource "azurerm_key_vault_secret" "storage_name" {
  name         = "storage-account-name"
  value        = azurerm_storage_account.sa.name
  key_vault_id = var.keyvault_id
  depends_on   = [var.keyvault_access_policy]

}

resource "azurerm_key_vault_secret" "storage_sas" {
  name         = "storage-sas-token"
  value        = data.azurerm_storage_account_sas.sas.sas
  key_vault_id = var.keyvault_id
  depends_on   = [var.keyvault_access_policy]
}

resource "azurerm_key_vault_secret" "container_name" {
  name         = "storage-container-name"
  value        = azurerm_storage_container.container.name
  key_vault_id = var.keyvault_id
  depends_on   = [var.keyvault_access_policy]
}
