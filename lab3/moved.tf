
//the rg identifier in tf was wrong so i had to change it without deleting the resource
moved {
  from = azurerm_resource_group.name
  to   = azurerm_resource_group.main
}