# Container Apps Environment + Container App, migrados a Azure Verified
# Modules el 2026-09-28 - mismo criterio que jalcalaroot-azure-bootstrap
# (ver su CLAUDE.md "Dev VNet" para el contexto completo de la decision).
#
# Internal-only a proposito (ver containerapps_subnet.tf en
# jalcalaroot-azure-bootstrap para el porque). Application Gateway es el
# unico punto de entrada publico; llega a este environment por su IP
# interna dentro de la VNet.
module "container_app_environment" {
  #checkov:skip=CKV_TF_1: pinned por version semver del Terraform Registry (no un git tag movible) - Azure Verified Module oficial de Microsoft, versiones inmutables. Mismo criterio ya documentado en jalcalaroot-azure-bootstrap/network.tf.
  source  = "Azure/avm-res-app-managedenvironment/azurerm"
  version = "0.5.0"

  name                = var.container_app_environment_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  enable_telemetry = false

  # infrastructure_subnet_id/internal_load_balancer_enabled (top-level) estan
  # deprecados en esta AVM en favor de vnet_configuration - confirmado
  # contra la doc del modulo antes de escribir esto, no adivinado.
  vnet_configuration = {
    infrastructure_subnet_id = var.network_containerapps_subnet_id
    internal                 = true
  }

  # log_analytics_workspace_id (variable suelta) tambien esta deprecada -
  # esta AVM quiere el objeto log_analytics_workspace = { resource_id = ... }.
  log_analytics_workspace = {
    resource_id = var.network_log_analytics_workspace_id
  }

  # workload_profiles (plural, list) - workload_profile (singular, set) esta
  # deprecado, mismo campo renombrado.
  workload_profiles = [
    {
      name                  = "Consumption"
      workload_profile_type = "Consumption"
    }
  ]
}

# Un environment interno NO registra su dominio por defecto en ninguna zona
# que la VNet pueda resolver - hay que crear la Private DNS Zone a mano con
# el nombre exacto de "default_domain" y linkearla a la VNet, si no
# Application Gateway nunca va a poder resolver el FQDN del Container App.
resource "azurerm_private_dns_zone" "containerapps" {
  name                = module.container_app_environment.default_domain
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "containerapps" {
  # azurerm v4.x (a donde bajamos el provider para poder usar las AVM de
  # Container Apps) usa resource_group_name+private_dns_zone_name en vez de
  # private_dns_zone_id directo - confirmado contra el schema real del
  # provider instalado (v5.x acepta el ID directo, v4.x no), no adivinado.
  name                  = "link-containerapps"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.containerapps.name
  virtual_network_id    = var.network_vnet_id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_dns_a_record" "containerapps_wildcard" {
  # Mismo motivo que el link de arriba - azurerm v4.x quiere zone_name +
  # resource_group_name, no private_dns_zone_id.
  name                = "*"
  zone_name           = azurerm_private_dns_zone.containerapps.name
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 300
  records             = [module.container_app_environment.static_ip_address]
}

module "container_app" {
  #checkov:skip=CKV_TF_1: pinned por version semver del Terraform Registry, no un git tag - ver el mismo skip arriba.
  source  = "Azure/avm-res-app-containerapp/azurerm"
  version = "0.9.0"

  name                                  = var.container_app_name
  location                              = azurerm_resource_group.this.location
  resource_group_name                   = azurerm_resource_group.this.name
  resource_group_id                     = azurerm_resource_group.this.id
  container_app_environment_resource_id = module.container_app_environment.resource_id
  revision_mode                         = "Single"
  tags                                  = local.tags

  enable_telemetry = false

  # managed_identities, no el bloque identity{} del recurso crudo -
  # identity_settings es una variable DISTINTA (lifecycle de la identidad
  # durante operaciones), no confundir las dos.
  managed_identities = {
    user_assigned_resource_ids = [azurerm_user_assigned_identity.containerapp_acr_pull.id]
  }

  # registries es una lista top-level, no un bloque anidado dentro de
  # template/containers como en el recurso crudo.
  registries = [
    {
      server   = azurerm_container_registry.this.login_server
      identity = azurerm_user_assigned_identity.containerapp_acr_pull.id
    }
  ]

  # min_replicas/max_replicas van directo en template, no en un sub-bloque
  # scale separado. containers es una lista, no un mapa por nombre.
  template = {
    containers = [
      {
        name   = "hello-world"
        image  = "${azurerm_container_registry.this.login_server}/hello-world:${var.container_image_tag}"
        cpu    = var.container_cpu
        memory = var.container_memory
      }
    ]
    min_replicas = 1
    max_replicas = 2
  }

  ingress = {
    external_enabled = true # "external" = alcanzable desde fuera del environment (App Gateway), no desde internet - el environment es internal-only
    target_port      = 80

    # Sin esto, el edge proxy de Container Apps fuerza HTTPS y devuelve 301
    # ante cualquier request HTTP plano - exactamente lo que le llega desde
    # Application Gateway (backend_http_settings usa protocol = "Http" en
    # app_gateway.tf). TLS ya termino en App Gateway con el cert de Let's
    # Encrypt; este tramo interno vive enteramente dentro de la VNet
    # (environment internal-only), asi que HTTP plano aca es la superficie
    # esperada, no una regresion de seguridad.
    allow_insecure_connections = true

    traffic_weight = [
      {
        latest_revision = true
        percentage      = 100
      }
    ]
  }

  depends_on = [azurerm_role_assignment.containerapp_acr_pull]
}
