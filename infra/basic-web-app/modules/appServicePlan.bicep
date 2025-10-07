// Module: App Service Plan (Linux P0v4)
param name string
param location string = resourceGroup().location
@description('Tags to apply to the App Service Plan')
param tags object = {}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: name
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  kind: 'linux'
  tags: tags
  properties: {
    reserved: true
  }
}

output appServicePlanName string = appServicePlan.name
output appServicePlanId string = appServicePlan.id
