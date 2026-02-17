param location string
param tags object
param resourceToken string
param sqlAdminUser string
@secure()
param sqlAdminPassword string

// ──────────────────────────────────────
// SQL Server + Database
// ──────────────────────────────────────

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: 'sql-server-${resourceToken}'
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdminUser
    administratorLoginPassword: sqlAdminPassword
  }
}

resource sqlFirewallAzure 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: 'sql-db'
  location: location
  tags: tags
  sku: {
    name: 'GP_S_Gen5_2'
    tier: 'GeneralPurpose'
  }
  properties: {
    useFreeLimit: true
    freeLimitExhaustionBehavior: 'AutoPause'
  }
}

// ──────────────────────────────────────
// Container Registry
// ──────────────────────────────────────

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: 'acr${resourceToken}'
  location: location
  tags: tags
  sku: { name: 'Basic' }
  properties: { adminUserEnabled: true }
}

// ──────────────────────────────────────
// Container Apps Environment
// ──────────────────────────────────────

resource cae 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'environment-${resourceToken}'
  location: location
  tags: tags
  properties: {}
}

// ──────────────────────────────────────
// DAB Container App (SAMI for Azure SQL auth)
// ──────────────────────────────────────

// SQL Auth connection string — used by SQL Commander (no SAMI)
var sqlConnString = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Database=sql-db;User Id=${sqlAdminUser};Password=${sqlAdminPassword};Encrypt=true;TrustServerCertificate=false'

// Managed Identity connection string — used by DAB
var sqlMiConnString = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Database=sql-db;Authentication=Active Directory Managed Identity;Encrypt=true;TrustServerCertificate=false'

resource dabApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'data-api-${resourceToken}'
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    managedEnvironmentId: cae.id
    configuration: {
      ingress: {
        external: true
        targetPort: 5000
      }
      registries: [
        {
          server: acr.properties.loginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        { name: 'db-conn', value: sqlMiConnString }
        { name: 'acr-password', value: acr.listCredentials().passwords[0].value }
      ]
    }
    template: {
      containers: [
        {
          name: 'dab-api'
          image: 'mcr.microsoft.com/azure-databases/data-api-builder:1.7.83-rc'
          resources: { cpu: json('0.5'), memory: '1Gi' }
          env: [
            { name: 'MSSQL_CONNECTION_STRING', secretRef: 'db-conn' }
          ]
        }
      ]
      scale: { minReplicas: 1, maxReplicas: 1 }
    }
  }
}

// ──────────────────────────────────────
// SQL Commander Container App
// ──────────────────────────────────────

resource sqlCmdr 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'sql-commander-${resourceToken}'
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: cae.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
      }
      secrets: [
        { name: 'db-conn', value: sqlConnString }
      ]
    }
    template: {
      containers: [
        {
          name: 'sql-commander'
          image: 'docker.io/jerrynixon/sql-commander:latest'
          resources: { cpu: json('0.25'), memory: '0.5Gi' }
          env: [
            { name: 'ConnectionStrings__db', secretRef: 'db-conn' }
          ]
        }
      ]
      scale: { minReplicas: 0, maxReplicas: 1 }
    }
  }
}

// ──────────────────────────────────────
// App Service (Web)
// ──────────────────────────────────────

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'service-plan-${resourceToken}'
  location: location
  tags: tags
  kind: 'linux'
  sku: { name: 'B1' }
  properties: { reserved: true }
}

resource webApp 'Microsoft.Web/sites@2024-04-01' = {
  name: 'web-app-${resourceToken}'
  location: location
  tags: tags
  kind: 'app,linux'
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      appCommandLine: 'pm2 serve /home/site/wwwroot --no-daemon --spa'
    }
  }
}

// ──────────────────────────────────────
// Outputs
// ──────────────────────────────────────

output resourceToken string = resourceToken
output sqlServerName string = sqlServer.name
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output acrName string = acr.name
output dabAppName string = dabApp.name
output dabAppPrincipalId string = dabApp.identity.principalId
output dabFqdn string = dabApp.properties.configuration.ingress.fqdn
output sqlCmdrFqdn string = sqlCmdr.properties.configuration.ingress.fqdn
output webAppName string = webApp.name
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
