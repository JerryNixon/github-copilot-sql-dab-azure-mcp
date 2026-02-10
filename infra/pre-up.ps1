# Pre-up hook — creates Entra ID resources before Bicep runs
# Runs automatically before `azd provision` or `azd up`

$ErrorActionPreference = "Stop"

$envName = $env:AZURE_ENV_NAME

# ── 1. App registration (idempotent) ──

Write-Host "Configuring Entra ID app registration..." -ForegroundColor Yellow
$appName = "app-$envName"
$localRedirect = "http://localhost:5173"
$appJson = az ad app list --display-name $appName --query "[0]"
$app = $appJson | ConvertFrom-Json

if (-not $app) {
    $app = az ad app create `
        --display-name $appName `
        --sign-in-audience "AzureADMyOrg" `
        --query "{appId: appId, id: id}" | ConvertFrom-Json
    Write-Host "App registration created: $appName" -ForegroundColor Green
} else {
    Write-Host "App registration exists: $appName" -ForegroundColor Gray
}

# Configure SPA redirect (localhost only — post-up adds Azure URL)
# and expose API scope for DAB authentication
$scopeId = [guid]::NewGuid().ToString()
$appPatch = @{
    spa = @{ redirectUris = @($localRedirect) }
    web = @{ redirectUris = @() }
    identifierUris = @("api://$($app.appId)")
    api = @{
        oauth2PermissionScopes = @(
            @{
                id = $scopeId
                adminConsentDisplayName = "Access TODO API"
                adminConsentDescription = "Allows the app to access the TODO API on behalf of the signed-in user"
                userConsentDisplayName = "Access TODO API"
                userConsentDescription = "Allows the app to access the TODO API on your behalf"
                isEnabled = $true
                type = "User"
                value = "access_as_user"
            }
        )
    }
} | ConvertTo-Json -Depth 4

$appPatch | Out-File -FilePath "temp-app-patch.json" -Encoding utf8
az rest --method PATCH `
    --uri "https://graph.microsoft.com/v1.0/applications/$($app.id)" `
    --headers "Content-Type=application/json" `
    --body "@temp-app-patch.json" | Out-Null
Remove-Item "temp-app-patch.json" -Force

# Pre-authorize the SPA to use the API scope (no consent prompt)
$preAuthConfig = @{
    api = @{
        preAuthorizedApplications = @(
            @{
                appId = $app.appId
                delegatedPermissionIds = @($scopeId)
            }
        )
    }
} | ConvertTo-Json -Depth 4

$preAuthConfig | Out-File -FilePath "temp-preauth.json" -Encoding utf8
az rest --method PATCH `
    --uri "https://graph.microsoft.com/v1.0/applications/$($app.id)" `
    --headers "Content-Type=application/json" `
    --body "@temp-preauth.json" | Out-Null
Remove-Item "temp-preauth.json" -Force
Write-Host "API scope exposed: api://$($app.appId)/access_as_user" -ForegroundColor Green

# Store clientId so post-up and local dev can use it
azd env set AZURE_CLIENT_ID $app.appId
Write-Host "Client ID stored: $($app.appId)" -ForegroundColor Green

# Store tenantId for consistency
$tenantId = (az account show --query tenantId -o tsv)
azd env set AZURE_TENANT_ID $tenantId
Write-Host "Tenant ID stored: $tenantId" -ForegroundColor Green

# ── 2. Update dab-config.json with real auth values ──

Write-Host "Updating DAB config with EntraId auth..." -ForegroundColor Yellow
Push-Location api
dab configure `
    --runtime.host.authentication.provider "EntraId" `
    --runtime.host.authentication.jwt.audience "api://$($app.appId)" `
    --runtime.host.authentication.jwt.issuer "https://login.microsoftonline.com/$tenantId/v2.0"
Pop-Location
Write-Host "DAB config updated" -ForegroundColor Green

# ── 3. Update local config.js for dev ──

$configContent = @"
const CONFIG = {
    clientId: '$($app.appId)',
    tenantId: '$tenantId',
    apiUrlLocal: 'http://localhost:5000',
    apiUrlAzure: '__API_URL_AZURE__'
};
"@
$configContent | Out-File -FilePath "web/config.js" -Encoding utf8 -Force
Write-Host "Local config.js updated" -ForegroundColor Green

# ── 4. Test user (idempotent) ──

Write-Host "Creating test user..." -ForegroundColor Yellow
$domainName = az ad signed-in-user show --query 'userPrincipalName' -o tsv | ForEach-Object { $_.Split('@')[1] }
$testUserPrincipal = "testuser-$envName@$domainName"
$existingUser = az ad user list --filter "userPrincipalName eq '$testUserPrincipal'" --query "[0]" | ConvertFrom-Json

if (-not $existingUser) {
    az ad user create `
        --display-name "Todo Test User" `
        --user-principal-name $testUserPrincipal `
        --password "TodoTest123!" `
        --force-change-password-next-sign-in false | Out-Null
    Write-Host "Test user created: $testUserPrincipal" -ForegroundColor Green
} else {
    Write-Host "Test user exists: $testUserPrincipal" -ForegroundColor Gray
}
