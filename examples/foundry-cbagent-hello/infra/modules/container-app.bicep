// Container App Environment + Container App

param location string
param resourceToken string
param tags object
param acrLoginServer string
param acrName string
param acrId string
param projectEndpoint string
param imageName string = ''

// ---------------------------------------------------------------------------
// User-assigned managed identity (created before the Container App so we
// can grant AcrPull *before* the first image pull)
// ---------------------------------------------------------------------------
resource agentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-agent-${resourceToken}'
  location: location
  tags: tags
}

// AcrPull role assignment – must complete before the Container App is created
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(agentIdentity.id, acrId, acrPullRoleId)
  scope: resourceGroup()
  properties: {
    principalId: agentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
  }
}

// Log Analytics workspace (required by Container App Environment)
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// Container App Environment
resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-${resourceToken}'
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// Container App – uses the user-assigned identity to pull from ACR
resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-agent-${resourceToken}'
  location: location
  tags: union(tags, { 'azd-service-name': 'agent' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${agentIdentity.id}': {}
    }
  }
  dependsOn: [acrPullRole] // ensure AcrPull is granted before first image pull
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8088
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: acrLoginServer
          identity: agentIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'agent'
          image: !empty(imageName) ? imageName : '${acrLoginServer}/agent:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'PROJECT_ENDPOINT'
              value: projectEndpoint
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
}

output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn
output containerAppName string = containerApp.name
