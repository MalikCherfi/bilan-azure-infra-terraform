output "keyvault_id" {
  value = azurerm_key_vault.keyvault.id
}
output "wait_for_access_policy" {
  value = time_sleep.wait_for_access_policy
}
