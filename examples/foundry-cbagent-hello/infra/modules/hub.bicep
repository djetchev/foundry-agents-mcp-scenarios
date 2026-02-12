// AI Foundry Hub + AI Services connection

param location string
param resourceToken string
param tags object
param storageAccountId string
param keyVaultId string
param aiServicesResourceId string
param aiServicesEndpoint string

resource hub 'Microsoft.MachineLearningServices/workspaces@2025-04-01' = {
  name: 'hub-${resourceToken}'
  location: location
  tags: tags
  kind: 'Hub'
  identity: { type: 'SystemAssigned' }
  sku: { name: 'Basic', tier: 'Basic' }
  properties: {
    friendlyName: 'Hello World Hub'
    storageAccount: storageAccountId
    keyVault: keyVaultId
    publicNetworkAccess: 'Enabled'
  }
}

resource aiServicesConnection 'Microsoft.MachineLearningServices/workspaces/connections@2025-04-01' = {
  parent: hub
  name: 'aiservices-connection'
  properties: {
    category: 'AIServices'
    authType: 'AAD'
    target: aiServicesEndpoint
    metadata: {
      ApiType: 'Azure'
      ResourceId: aiServicesResourceId
    }
  }
}

output hubId string = hub.id
output hubName string = hub.name
