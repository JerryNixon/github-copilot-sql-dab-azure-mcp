# Entra ID setup — creates app registration and .azure-env

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path "$PSScriptRoot/..").Path
$azureEnvFile = "$repoRoot/.azure-env"

$isAzd = [bool]$env:AZURE_ENV_NAME
$localRedirect = "http://localhost:5173"

# ── 0. Token management ──

if (Test-Path $azureEnvFile) {
    $envData = @{}
    Get-Content $azureEnvFile | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
        $parts = $_ -split '=', 2
        $envData[$parts[0].Trim()] = $parts[1].Trim()
    }
    $token = $envData['token']
    Write-Host "Using existing token: $token" -ForegroundColor Gray
} else {
    $token = (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmm')
    Write-Host "Generated token: $token" -ForegroundColor Green
}

if ($isAzd) {
    azd env set AZURE_RESOURCE_TOKEN $token
}

$appName = "app-$token"

# ── 1. App registration (idempotent) ──

Write-Host "Configuring Entra ID app registration..." -ForegroundColor Yellow
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

# Reuse existing scope ID if present (avoids CannotDeleteOrUpdateEnabledEntitlement error)
$existingScopeId = az ad app show --id $app.appId --query "api.oauth2PermissionScopes[?value=='access_as_user'].id | [0]" -o tsv
if ($existingScopeId) {
    $scopeId = $existingScopeId
    Write-Host "Using existing scope: $scopeId" -ForegroundColor Gray
} else {
    $scopeId = [guid]::NewGuid().ToString()
}
$appPatch = @{
    spa = @{ redirectUris = @($localRedirect) }
    web = @{ redirectUris = @() }
    identifierUris = @("api://$($app.appId)")
    api = @{
        requestedAccessTokenVersion = 2
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

$appPatch | Out-File -FilePath "$repoRoot/temp-app-patch.json" -Encoding utf8
az rest --method PATCH `
    --uri "https://graph.microsoft.com/v1.0/applications/$($app.id)" `
    --headers "Content-Type=application/json" `
    --body "@$repoRoot/temp-app-patch.json" | Out-Null
Remove-Item "$repoRoot/temp-app-patch.json" -Force

# Pre-authorize the SPA (no consent prompt)
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

$preAuthConfig | Out-File -FilePath "$repoRoot/temp-preauth.json" -Encoding utf8
az rest --method PATCH `
    --uri "https://graph.microsoft.com/v1.0/applications/$($app.id)" `
    --headers "Content-Type=application/json" `
    --body "@$repoRoot/temp-preauth.json" | Out-Null
Remove-Item "$repoRoot/temp-preauth.json" -Force
Write-Host "API scope exposed: api://$($app.appId)/access_as_user" -ForegroundColor Green

$tenantId = (az account show --query tenantId -o tsv)

# Store values for azd if running under azd
if ($isAzd) {
    azd env set AZURE_CLIENT_ID $app.appId
    azd env set AZURE_TENANT_ID $tenantId
    Write-Host "Stored CLIENT_ID + TENANT_ID in azd env" -ForegroundColor Green
}

# ── 2. Update dab-config.json with real auth values ──

Write-Host "Updating DAB config with EntraId auth..." -ForegroundColor Yellow
Push-Location "$repoRoot/api"
dab configure `
    --runtime.host.authentication.provider "EntraId" `
    --runtime.host.authentication.jwt.audience "$($app.appId)" `
    --runtime.host.authentication.jwt.issuer "https://login.microsoftonline.com/$tenantId/v2.0"
Pop-Location
Write-Host "DAB config updated" -ForegroundColor Green

# ── 3. Update config.js ──

$configContent = @"
const CONFIG = {
    clientId: '$($app.appId)',
    tenantId: '$tenantId',
    apiUrlLocal: 'http://localhost:5000',
    apiUrlAzure: '__API_URL_AZURE__'
};
"@
$configContent | Out-File -FilePath "$repoRoot/web/config.js" -Encoding utf8 -Force
Write-Host "config.js updated" -ForegroundColor Green

# ── 4. Write .azure-env ──

@"
# Auto-generated. Do not edit. Delete to reset.
token=$token
resource-group=rg-quickstart3-$token
sql-server=sql-server-$token
sql-database=sql-db
container-registry=acr$token
environment=environment-$token
data-api=data-api-$token
sql-commander=sql-commander-$token
service-plan=service-plan-$token
web-app=web-app-$token
app-registration=$appName
"@ | Out-File -FilePath $azureEnvFile -Encoding utf8 -Force
Write-Host "Environment written to .azure-env" -ForegroundColor Green

# ── 5. Verify config files were updated ──

$failed = @()
$configJsContent = Get-Content "$repoRoot/web/config.js" -Raw
if ($configJsContent -match '__CLIENT_ID__|__TENANT_ID__') {
    $failed += "web/config.js still contains placeholders"
}
$dabConfigContent = Get-Content "$repoRoot/api/dab-config.json" -Raw
if ($dabConfigContent -match '__AUDIENCE__|__ISSUER__') {
    $failed += "api/dab-config.json still contains placeholders"
}
if ($failed.Count -gt 0) {
    foreach ($f in $failed) { Write-Host "✗ $f" -ForegroundColor Red }
    exit 1
}
Write-Host "✓ All config files verified" -ForegroundColor Green
