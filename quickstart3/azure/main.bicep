targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the azd environment')
param environmentName string

@description('Primary location for all resources')
param location string

@secure()
@description('SQL Server administrator password')
param sqlAdminPassword string

param sqlAdminUser string = 'sqladmin'

var tags = { 'azd-env-name': environmentName }

@description('Token suffix for resource names (set by entra-setup.ps1, falls back to uniqueString)')
param resourceToken string = ''

var effectiveToken = empty(resourceToken) ? uniqueString(subscription().id, environmentName, location) : resourceToken

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-quickstart3-${effectiveToken}'
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  scope: rg
  name: 'resources'
  params: {
    location: location
    tags: tags
    resourceToken: effectiveToken
    sqlAdminUser: sqlAdminUser
    sqlAdminPassword: sqlAdminPassword
  }
}

// Outputs — available as env vars in post-up hook
output AZURE_ENV_NAME string = environmentName
output AZURE_RESOURCE_TOKEN string = effectiveToken
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_SQL_SERVER_NAME string = resources.outputs.sqlServerName
output AZURE_SQL_SERVER_FQDN string = resources.outputs.sqlServerFqdn
output AZURE_SQL_DATABASE string = 'sql-db'
output AZURE_SQL_ADMIN_USER string = sqlAdminUser
output AZURE_ACR_NAME string = resources.outputs.acrName
output AZURE_WEB_APP_NAME string = resources.outputs.webAppName
output AZURE_WEB_APP_URL string = resources.outputs.webAppUrl
output AZURE_CONTAINER_APP_API_NAME string = resources.outputs.dabAppName
output AZURE_CONTAINER_APP_API_PRINCIPAL_ID string = resources.outputs.dabAppPrincipalId
output AZURE_CONTAINER_APP_API_FQDN string = resources.outputs.dabFqdn
output AZURE_CONTAINER_APP_SQLCMDR_FQDN string = resources.outputs.sqlCmdrFqdn
