// get self, entra tenant info etc for group creation
data "azuread_client_config" "current" {}


// we turn our array into a map with element as the key
locals {
  remote_access_users_map = {for idx, element in var.remote_access_users : element => idx }
}


// iterate over a map of users to access them as tf objects to later extract their object id
data "azuread_user" "remote_access_users" {
  for_each = local.remote_access_users_map

  user_principal_name = each.key
}

// entra id group creation
resource "azuread_group" "remote_access_users" {
  display_name     = "${var.application_name}-${var.environment_name}-remote-access-users"
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

// add members from the array to group by taking their object id from entra
resource "azuread_group_member" "remote_access_membership" {
   for_each = local.remote_access_users_map
  
  group_object_id  = azuread_group.remote_access_users.object_id
  member_object_id = data.azuread_user.remote_access_users[each.key].object_id
}

