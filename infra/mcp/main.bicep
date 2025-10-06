// Bicep template: Flex Consumption Azure Function (.NET 9 isolated) with managed identity + identity-based Storage access
// Simplified first pass: storage public network access enabled (can be hardened later)
// Resources are prefixed via the `prefix` parameter. Includes Log Analytics + workspace-based Application Insights.
// NOTE: Identity-based primary storage access for WebJobs host is an evolving capability. Ensure your runtime supports
// managed identity for AzureWebJobsStorage before removing fallback options. No key-based connection string is exposed here.

@description('Resource name prefix (lowercase letters/numbers, 3-12 chars). Used to derive resource names.')
@minLength(3)
@maxLength(12)
@allowed([ 'mcpdemo', 'mcptest', 'mcp' ]) // Adjust or remove allowed list as needed
param prefix string = 'mcp'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Function App name (must be globally unique for DNS). Default combines prefix + func.')
param functionAppName string = toLower(format('{0}-func', prefix))

@description('Override storage account name (3-24 lowercase). Leave empty to auto-generate from prefix + uniqueString.')
@minLength(0)
@maxLength(24)
param storageAccountName string = ''

@description('Log Analytics workspace name.')
param logAnalyticsWorkspaceName string = format('{0}-law', prefix)

@description('Application Insights component name.')
param appInsightsName string = format('{0}-appi', prefix)

@description('Optional tags to apply to all resources.')
param tags object = {
  environment: 'dev'
  workload: 'mcp'
}

// ======== Variables ========
var storageSku = 'Standard_LRS'
var roleBlobDataContributor = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var roleQueueDataContributor = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
// Generate storage base name (prefix + 'st' + unique). Truncate only if >24 chars.
var generatedStorageBase = toLower(format('{0}st{1}', replace(prefix, '-', ''), uniqueString(resourceGroup().id, prefix)))
var generatedStorage = length(generatedStorageBase) > 24 ? substring(generatedStorageBase, 0, 24) : generatedStorageBase
// Effective storage account name prefers explicit param when provided
var effectiveStorageAccountName = empty(storageAccountName) ? generatedStorage : toLower(storageAccountName)

// ======== Log Analytics Workspace ========
resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    sku: {
      name: 'PerGB2018'
    }
  }
}

// ======== Application Insights (Workspace-based) ========
resource appi 'Microsoft.Insights/components@2022-06-15' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    WorkspaceResourceId: law.id
    IngestionMode: 'ApplicationInsights'
  }
}

// ======== Storage Account ========
resource storage 'Microsoft.Storage/storageAccounts@2023-04-01' = {
  name: effectiveStorageAccountName
  location: location
  tags: tags
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    allowSharedKeyAccess: true // Keep true for now; can disable once identity-only is fully supported
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow' // Public for first pass; set to Deny + rules/private endpoints later
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: { enabled: true }
        file: { enabled: true }
        queue: { enabled: true }
        table: { enabled: true }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// ======== Flex Consumption Plan ========
resource funcPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: format('{0}-plan', prefix)
  location: location
  kind: 'functionapp'
  tags: tags
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  properties: {
    // Additional plan properties can be added if exposed for Flex Consumption in future API versions.
  }
}

// ======== Function App (.NET isolated) ========
resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: funcPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~5'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appi.properties.ConnectionString
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appi.properties.InstrumentationKey
        }
        // Identity-based Storage (preview / evolving). Ensure runtime support.
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storage.name
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        // If fallback using key is needed, you would add AzureWebJobsStorage with a connection string instead.
      ]
      linuxFxVersion: '' // For dotnet isolated Functions host chooses runtime; leave blank
      ftpsState: 'Disabled'
      alwaysOn: false // Flex Consumption does not require AlwaysOn
      minimumElasticInstanceCount: 0
    }
  }
  dependsOn: [
    storage
    funcPlan
    appi
  ]
}

// ======== Role Assignments (Storage Data Access) ========
resource roleBlob 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(functionApp.id, storage.id, roleBlobDataContributor)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleBlobDataContributor)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [ functionApp ]
}

resource roleQueue 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(functionApp.id, storage.id, roleQueueDataContributor)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleQueueDataContributor)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [ functionApp ]
}

// ======== Outputs ========
@description('Deployed Function App name')
output functionAppName string = functionApp.name

@description('Function App default hostname')
output functionAppHostname string = functionApp.properties.defaultHostName

@description('Managed identity principalId')
output functionAppPrincipalId string = functionApp.identity.principalId

@description('Storage account name')
output storageName string = storage.name

@description('Application Insights Connection String')
output appInsightsConnectionString string = appi.properties.ConnectionString
