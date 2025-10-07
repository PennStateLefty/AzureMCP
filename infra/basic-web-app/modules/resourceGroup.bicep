targetScope = 'subscription'

// Module: resourceGroup
// Creates a resource group (subscription-scope module)
// Simplified for demo: takes explicit location and tags
param name string
param location string
@description('Tags to apply to the resource group')
param tags object = {}

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: name
  location: location
  tags: tags
}

output resourceGroupName string = rg.name
output resourceGroupId string = rg.id
