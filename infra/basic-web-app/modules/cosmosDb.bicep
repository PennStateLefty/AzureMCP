// Module: Cosmos DB (Serverless)
param name string
param location string = resourceGroup().location
@description('Tags to apply to the Cosmos DB account')
param tags object = {}

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: name
  location: location
  kind: 'GlobalDocumentDB'
  tags: tags
  properties: {
    databaseAccountOfferType: 'Standard'
    enableFreeTier: true
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

output cosmosDbName string = cosmosDb.name
output cosmosDbId string = cosmosDb.id
