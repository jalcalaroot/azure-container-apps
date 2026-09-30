variable "subscription_id" {
  description = "Subscription ID de Azure - requerido explicitamente por el provider azurerm >= 4.0. Sin default a proposito: pasarlo via -var, un .tfvars gitignoreado, o TF_VAR_subscription_id (NO usar ARM_SUBSCRIPTION_ID, el provider no lo lee)."
  type        = string
}

variable "location" {
  description = "Azure region - debe coincidir con la region de la VNet real (vnet-jalcalaroot vive en eastus, vease jalcalaroot-azure-bootstrap)"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Resource group dedicado a este proyecto (lifecycle propio, no compartido con azure-virtual-network)"
  type        = string
  default     = "rg-containerapps"
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Propietario/responsable del recurso"
  type        = string
  default     = "johan"
}

variable "project" {
  description = "Nombre del proyecto asociado"
  type        = string
  default     = "container-apps"
}

variable "tags" {
  description = "Tags adicionales a fusionar con los tags base"
  type        = map(string)
  default     = {}
}

# ============================================================================
# Valores copiados de los outputs de azure-virtual-network (mismo patron que
# el resto de proyectos consumidores del workspace - sin terraform_remote_state,
# solo valores copiados a mano tras aplicar ese proyecto).
# ============================================================================

variable "network_containerapps_subnet_id" {
  description = "azure-virtual-network output: containerapps_subnet_id"
  type        = string
}

variable "network_appgw_subnet_id" {
  description = "azure-virtual-network output: appgw_subnet_id"
  type        = string
}

variable "network_vnet_id" {
  description = "azure-virtual-network output: vnet_id (para linkear la Private DNS Zone del Container Apps Environment)"
  type        = string
}

variable "network_log_analytics_workspace_id" {
  description = "azure-virtual-network output: log_analytics_workspace_id - reutilizamos el mismo workspace, no creamos uno nuevo"
  type        = string
}

# ============================================================================
# Nombres de recursos (globalmente unicos donde aplique)
# ============================================================================

variable "acr_name" {
  description = "Nombre del Azure Container Registry - debe ser unico globalmente, solo alfanumerico"
  type        = string
  # "acrcontainerapps" (default original) ya esta tomado globalmente por
  # otra cuenta de Azure sin relacion con nosotros (confirmado con
  # `az acr check-name` - no aparece en `az acr list` de esta suscripcion,
  # asi que no es un residuo nuestro). Los nombres de ACR son unicos a nivel
  # de todo Azure, no solo de esta cuenta.
  default = "acrjalcalarootapps"
}

variable "key_vault_name" {
  description = "Nombre del Key Vault dedicado a este proyecto - debe ser unico globalmente, 3-24 caracteres alfanumericos. 'kv-containerapps' devolvia VaultAlreadyExists (409) en 4 intentos de apply consecutivos pese a que az keyvault check-name/list/list-deleted lo mostraban disponible - mismo patron que el nombre de ACR (acrcontainerapps) que resulto estar tomado globalmente por otra cuenta (ver acr.tf). Renombrado el 2026-09-28; check-name confirmado para el nuevo nombre antes de aplicar."
  type        = string
  default     = "kv-jalcalaroot-capps"
}

variable "container_app_environment_name" {
  description = "Nombre del Container Apps Environment"
  type        = string
  default     = "cae-containerapps"
}

variable "container_app_name" {
  description = "Nombre del Container App"
  type        = string
  default     = "hello-world"
}

variable "container_image_tag" {
  description = "Tag de la imagen en ACR a desplegar (formato <acr-login-server>/hello-world:<tag>). La imagen debe existir en ACR ANTES de aplicar container_apps.tf - ver README para el build/push."
  type        = string
  default     = "latest"
}

variable "container_cpu" {
  description = "vCPU asignada al container (plan Consumption - cpu+memory deben sumar una combinacion valida)"
  type        = number
  default     = 0.25
}

variable "container_memory" {
  description = "Memoria asignada al container (plan Consumption)"
  type        = string
  default     = "0.5Gi"
}

# ============================================================================
# DNS + certificado
# ============================================================================

variable "dns_zone_name" {
  description = "Nombre de la Azure DNS Zone EXISTENTE (ya delegada) donde se agrega el registro de este proyecto. No la creamos aqui - ver dns.tf."
  type        = string
  default     = "azure.jalcalaroot.com"
}

variable "dns_zone_resource_group_name" {
  description = "Resource group donde vive la Azure DNS Zone existente (distinto del resource group de este proyecto)"
  type        = string
  default     = "jalcalaroot"
}

variable "dns_record_name" {
  description = "Nombre del registro A dentro de dns_zone_name -> FQDN final = <dns_record_name>.<dns_zone_name>"
  type        = string
  default     = "container"
}

variable "acme_email" {
  description = "Email para la cuenta ACME de Let's Encrypt (avisos de expiracion, etc.). Sin default a proposito."
  type        = string
}

variable "acme_server_url" {
  description = "Endpoint del directorio ACME. Usa el de staging mientras iteras (los limites de tasa de produccion son estrictos: 5 duplicados/semana) y cambia a produccion solo para la validacion final."
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}

# ============================================================================
# Application Gateway
# ============================================================================

variable "app_gateway_name" {
  description = "Nombre del Application Gateway"
  type        = string
  default     = "appgw-containerapps"
}

variable "app_gateway_sku_capacity" {
  description = "Capacidad (instancias) del Application Gateway v2. 1 alcanza para este nivel de trafico."
  type        = number
  default     = 1
}

variable "extra_key_vault_admin_object_ids" {
  description = <<-EOT
    Object IDs adicionales (ademas de quien corre Terraform ahora mismo) que
    deben tener 'Key Vault Administrator' sobre el vault de este proyecto -
    p.ej. el principal_id de la identidad ci_agent (ver ci_identities.tf),
    que la PRIMERA vez que corre necesita poder leer
    azurerm_key_vault_certificate.this ANTES de que el propio apply cree su
    role assignment (un 403 real que tumbo la primera corrida del pipeline
    la vez anterior), o el object ID de un humano que necesite acceso de
    administrador via el portal. No tiene default hardcodeado a proposito
    (repo publico) - pasar via TF_VAR_extra_key_vault_admin_object_ids
    (JSON list) o un .tfvars gitignoreado. En CI viene de la GitHub
    variable EXTRA_KEY_VAULT_ADMIN_OBJECT_IDS.
  EOT
  type        = list(string)
  default     = []
}
