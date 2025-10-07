// Module: Service Bus Namespace (Standard)
param name string
param location string = resourceGroup().location
@description('Tags to apply to the Service Bus namespace')
param tags object = {}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: name
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  tags: tags
  properties: {
    zoneRedundant: false
  }
}

output serviceBusName string = serviceBus.name
output serviceBusId string = serviceBus.id
