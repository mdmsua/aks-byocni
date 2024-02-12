variable "spec" {
  type = object({
    project         = string
    tenant_id       = string
    subscription_id = string
    location        = string
    zones           = set(string)
    virtual_network = object({
      address_space = list(string)
    })
    cluster = object({
      id            = number
      version       = string
      pod_cidrs     = list(string)
      service_cidrs = list(string)
      default_node_pool = object({
        min_count       = number
        max_count       = number
        max_pods        = number
        vm_size         = string
        os_disk_size_gb = number
        os_disk_type    = string
        os_sku          = string
        max_surge       = string
      })
      node_pools = set(object({
        name            = string
        mode            = string
        min_count       = number
        max_count       = number
        max_pods        = number
        vm_size         = string
        os_disk_size_gb = number
        os_disk_type    = string
        os_sku          = string
        max_surge       = string
      }))
      admins = set(string)
    })
    charts = object({
      cilium = object({
        version = string
      })
    })
  })
}

variable "tfc_azure_dynamic_credentials" {
  type = object({
    default = object({
      client_id_file_path  = string
      oidc_token_file_path = string
    })
    aliases = map(object({
      client_id_file_path  = string
      oidc_token_file_path = string
    }))
  })
}
