// Demo deployment: minimal parameters (Project_Name, Location, Owning Team)
// This template must be deployed at subscription scope because it creates a resource group.
targetScope = 'subscription'

@description('Project name (may contain spaces) – will be normalized for resource naming')
@maxLength(60)
param projectName string

@description('Azure region for all resources (restricted for demo)')
@allowed([
  'eastus'
  'westus2'
  'centralus'
  'westeurope'
  'northeurope'
  'uksouth'
  'southeastasia'
])
param location string

@description('Owning team name applied as a tag on all resources')
param owningTeam string

@description('SQL Server administrator password')
@secure()
param sqlAdminPassword string

// Normalize project name: remove spaces, lowercase
var normalizedProject = toLower(replace(projectName, ' ', ''))

// Derive resource names (simple deterministic pattern). Truncate where global name length limits apply.
var rgName = 'rg-${normalizedProject}'
var aspName = 'asp-${normalizedProject}'
var sqlDatabaseName = 'sqldb-${normalizedProject}-${take(uniqueString(subscription().id, normalizedProject), 6)}'
var sbName = 'sb-${normalizedProject}'
// Storage account: must be globally unique, <=24, lowercase alphanumeric. Basic shortening + uniqueString salt.
var storageBase = take(replace(normalizedProject, '-', ''), 10)
var storageAccountName = '${storageBase}${take(uniqueString(subscription().id, normalizedProject), 14)}'

// Common tags
var commonTags = {
  OwningTeam: owningTeam
  Project: normalizedProject
  DeploymentType: 'demo'
}

// 1. Resource Group
module rgModule './modules/resourceGroup.bicep' = {
  name: 'rg-${normalizedProject}'
  params: {
    name: rgName
    location: location
    tags: commonTags
  }
}

// 2. App Service Plan (scoped to RG)
module appServicePlanModule './modules/appServicePlan.bicep' = {
  name: 'asp-${normalizedProject}'
  scope: resourceGroup(rgName)
  params: {
    name: aspName
    location: location
    tags: commonTags
  }
  dependsOn: [rgModule]
}

// 3. SQL Database (Basic tier - cheapest)
module sqlDatabaseModule './modules/sqlDatabase.bicep' = {
  name: 'sqldb-${normalizedProject}'
  scope: resourceGroup(rgName)
  params: {
    name: sqlDatabaseName
    location: location
    tags: commonTags
    sqlAdminPassword: sqlAdminPassword
  }
  dependsOn: [rgModule]
}

// 4. Service Bus
module serviceBusModule './modules/serviceBus.bicep' = {
  name: 'sb-${normalizedProject}'
  scope: resourceGroup(rgName)
  params: {
    name: sbName
    location: location
    tags: commonTags
  }
  dependsOn: [rgModule]
}

// 5. Storage Account (shared key disabled inside module)
module storageAccountModule './modules/storageAccount.bicep' = {
  name: 'stg-${normalizedProject}'
  scope: resourceGroup(rgName)
  params: {
    name: storageAccountName
    location: location
    tags: commonTags
  }
  dependsOn: [rgModule]
}

// Outputs
output resourceGroupName string = rgName
output appServicePlanName string = aspName
output sqlServerName string = sqlDatabaseModule.outputs.sqlServerName
output sqlDatabaseName string = sqlDatabaseModule.outputs.sqlDatabaseName
output serviceBusName string = sbName
output storageAccountName string = storageAccountName
