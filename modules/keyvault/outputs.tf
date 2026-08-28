output "key_vault_id" {
  value = azurerm_key_vault.keyvault.id
}

output "keyvault_access_policy" {
  value = azurerm_key_vault_access_policy.keyvault_access_policy
}

output "wait_for_access_policy" {
  value = time_sleep.wait_for_access_policy
}
