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

// Normalize project name: remove spaces, lowercase
var normalizedProject = toLower(replace(projectName, ' ', ''))

// Derive resource names (simple deterministic pattern). Truncate where global name length limits apply.
var rgName = '${normalizedProject}-rg'
var aspName = '${normalizedProject}-asp'
var cosmosName = '${normalizedProject}-cosmos'
var sbName = '${normalizedProject}-sb'
// Storage account: must be globally unique, <=24, lowercase alphanumeric. Basic shortening + uniqueString salt.
var storageBase = take(replace(normalizedProject, '-', ''), 12)
var storageAccountName = take('${storageBase}${uniqueString(subscription().id, normalizedProject)}', 24)

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
}

// 3. Cosmos DB (serverless)
module cosmosDbModule './modules/cosmosDb.bicep' = {
  name: 'cosmos-${normalizedProject}'
  scope: resourceGroup(rgName)
  params: {
    name: cosmosName
    location: location
    tags: commonTags
  }
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
}

// Outputs
output resourceGroupName string = rgName
output appServicePlanName string = aspName
output cosmosDbName string = cosmosName
output serviceBusName string = sbName
output storageAccountName string = storageAccountName
