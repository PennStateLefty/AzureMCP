// Module: Azure SQL Database (Basic tier - cheapest option)
param name string
param location string = resourceGroup().location
@description('Tags to apply to the SQL server and database')
param tags object = {}

// SQL Server (logical server)
resource sqlServer 'Microsoft.Sql/servers@2023-02-01-preview' = {
  name: '${name}-server'
  location: location
  tags: tags
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: 'P@ssw0rd123!' // Note: In production, use Key Vault reference
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

// SQL Database (Basic tier - cheapest)
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-02-01-preview' = {
  parent: sqlServer
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {
    maxSizeBytes: 2147483648 // 2GB
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}

// Allow Azure services to access the server
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-02-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output sqlServerName string = sqlServer.name
output sqlDatabaseName string = sqlDatabase.name
output sqlServerId string = sqlServer.id
output sqlDatabaseId string = sqlDatabase.id
