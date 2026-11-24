
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  environment_prefix =  "${var.application_name}-${var.environment_name}-${random_string.suffix.result}"
  regional_stamps = {
    "foo"= {
        region = "westus"
        min_nodes_count = 4
        max_nodes_count = 8
    },
    "bar" = {
        region = "eastus"
        min_nodes_count = 4
        max_nodes_count = 8
    }
  }
}

module "regional_stamps" {
    source = "./modules/regional-stamp"

    for_each = local.regional_stamps

    region = each.value.region
    name = each.key
    min_nodes_count = each.value.min_nodes_count
    max_node_count = each.value.max_nodes_count
}










