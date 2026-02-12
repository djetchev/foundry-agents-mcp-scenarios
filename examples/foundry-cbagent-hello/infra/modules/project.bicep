// AI Foundry Project (child of Hub)

param location string
param resourceToken string
param tags object
param hubId string

resource project 'Microsoft.MachineLearningServices/workspaces@2025-04-01' = {
  name: 'proj-hello-${resourceToken}'
  location: location
  tags: tags
  kind: 'Project'
  identity: { type: 'SystemAssigned' }
  sku: { name: 'Basic', tier: 'Basic' }
  properties: {
    friendlyName: 'HelloWorld Agent Project'
    hubResourceId: hubId
    publicNetworkAccess: 'Enabled'
  }
}

output projectName string = project.name
output projectEndpoint string = project.properties.discoveryUrl
