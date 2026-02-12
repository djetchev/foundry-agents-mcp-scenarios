// ---------------------------------------------------------------------------
// AI Foundry – Hub + Project (public networking, no VNet)
// ---------------------------------------------------------------------------
// Creates a Hub workspace, connects an existing AI Services resource, and
// provisions a lightweight Project underneath.  All resources use public
// network access.
// ---------------------------------------------------------------------------

targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the azd environment – used to derive unique resource names.')
param environmentName string

@minLength(1)
@description('Primary Azure region for all resources.')
param location string

@description('Resource ID of an existing AI Services (CognitiveServices) account to connect to the Hub.')
param aiServicesResourceId string

@description('Endpoint URL of the existing AI Services account (e.g. https://<name>.cognitiveservices.azure.com/).')
param aiServicesEndpoint string

// ---------------------------------------------------------------------------
// Derived names
// ---------------------------------------------------------------------------
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// ---------------------------------------------------------------------------
// Resource group
// ---------------------------------------------------------------------------
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

// ---------------------------------------------------------------------------
// Backing services required by the Hub (Storage + Key Vault)
// ---------------------------------------------------------------------------
module hubDeps './modules/hub-dependencies.bicep' = {
  name: 'hubDeps'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// AI Foundry Hub
// ---------------------------------------------------------------------------
module hub './modules/hub.bicep' = {
  name: 'hub'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    tags: tags
    storageAccountId: hubDeps.outputs.storageAccountId
    keyVaultId: hubDeps.outputs.keyVaultId
    aiServicesResourceId: aiServicesResourceId
    aiServicesEndpoint: aiServicesEndpoint
  }
}

// ---------------------------------------------------------------------------
// AI Foundry Project
// ---------------------------------------------------------------------------
module project './modules/project.bicep' = {
  name: 'project'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    tags: tags
    hubId: hub.outputs.hubId
  }
}

// ---------------------------------------------------------------------------
// Container Registry
// ---------------------------------------------------------------------------
module acr './modules/container-registry.bicep' = {
  name: 'acr'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Container App Environment + Container App
// ---------------------------------------------------------------------------
module containerApp './modules/container-app.bicep' = {
  name: 'containerApp'
  scope: rg
  params: {
    location: location
    resourceToken: resourceToken
    tags: tags
    acrLoginServer: acr.outputs.acrLoginServer
    acrName: acr.outputs.acrName
    acrId: acr.outputs.acrId
    projectEndpoint: project.outputs.projectEndpoint
  }
}

// ---------------------------------------------------------------------------
// Outputs – consumed by azd and the agent at runtime
// ---------------------------------------------------------------------------
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = acr.outputs.acrLoginServer
output AZURE_CONTAINER_REGISTRY_NAME string = acr.outputs.acrName
output PROJECT_NAME string = project.outputs.projectName
output PROJECT_ENDPOINT string = project.outputs.projectEndpoint
output AGENT_FQDN string = containerApp.outputs.containerAppFqdn
