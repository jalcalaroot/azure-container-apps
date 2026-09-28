output "fqdn" {
  description = "Dominio publico final (una vez delegado el DNS)"
  value       = local.fqdn
}

output "app_gateway_public_ip" {
  description = "IP publica del Application Gateway - usarla si delegas el dominio manualmente en vez de vía este proyecto"
  value       = azurerm_public_ip.appgw.ip_address
}

output "acr_login_server" {
  description = "Login server del ACR - usar para docker build/push (ver README)"
  value       = azurerm_container_registry.this.login_server
}

output "container_app_environment_default_domain" {
  description = "Dominio interno del Container Apps Environment (usado por la Private DNS Zone)"
  value       = module.container_app_environment.default_domain
}

output "container_app_fqdn" {
  description = "FQDN interno del Container App (solo resoluble dentro de la VNet)"
  # La AVM no expone el FQDN pelado (sin esquema) directo - fqdn_url trae el
  # prefijo "https://" incluido (es una URL completa, no un hostname). Se
  # pela aca para mantener el mismo formato que el output/uso previo
  # (bare FQDN, consumido tal cual en el backend pool de Application
  # Gateway - ver app_gateway.tf).
  value = trimprefix(module.container_app.fqdn_url, "https://")
}

output "key_vault_name" {
  description = "Nombre del Key Vault dedicado a este proyecto"
  value       = azurerm_key_vault.this.name
}
