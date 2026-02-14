# Entra ID setup — creates app registration, test user, and .azure-env

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
$domainName = az ad signed-in-user show --query 'userPrincipalName' -o tsv | ForEach-Object { $_.Split('@')[1] }
$testUserPrincipal = "testuser-$token@$domainName"

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
    appRoles = @(
        @{
            id = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
            allowedMemberTypes = @("User")
            displayName = "Sample Role 1"
            description = "Sample application role for demo purposes"
            isEnabled = $true
            value = "sample-role-1"
        }
    )
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

# ── 4. Test user (idempotent) ──

Write-Host "Creating test user..." -ForegroundColor Yellow
$existingUser = az ad user list --filter "userPrincipalName eq '$testUserPrincipal'" --query "[0]" | ConvertFrom-Json

if (-not $existingUser) {
    az ad user create `
        --display-name "Test User" `
        --user-principal-name $testUserPrincipal `
        --password "TodoTest123!" `
        --force-change-password-next-sign-in false | Out-Null
    Write-Host "Test user created: $testUserPrincipal" -ForegroundColor Green
} else {
    Write-Host "Test user exists: $testUserPrincipal" -ForegroundColor Gray
}

# Write .azure-env (gitignored) with token and all resource names
$isNew = -not (Test-Path $azureEnvFile)
@"
# Auto-generated. Do not edit. Delete to reset.
token=$token
resource-group=rg-$token
sql-server=sql-server-$token
sql-database=sql-db
container-registry=acr$token
environment=environment-$token
data-api=data-api-$token
sql-commander=sql-commander-$token
service-plan=service-plan-$token
web-app=web-app-$token
app-registration=$appName
username=$testUserPrincipal
password=TodoTest123!
"@ | Out-File -FilePath $azureEnvFile -Encoding utf8 -Force
Write-Host "Environment written to .azure-env" -ForegroundColor Green

# Open in Notepad on first creation so user can save/copy credentials
if ($isNew) {
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        Start-Process notepad $azureEnvFile
    } elseif ($IsMacOS) {
        Start-Process open $azureEnvFile
    } else {
        Start-Process xdg-open $azureEnvFile 2>$null
    }
}

# ── 5. Assign App Role to test user ──

Write-Host "Assigning sample-role-1 to test user..." -ForegroundColor Yellow
$testUser = az ad user list --filter "userPrincipalName eq '$testUserPrincipal'" --query "[0].id" -o tsv
$sp = az ad sp list --filter "appId eq '$($app.appId)'" --query "[0].id" -o tsv
if (-not $sp) {
    $sp = (az ad sp create --id $app.appId --query id -o tsv)
    Write-Host "Service principal created" -ForegroundColor Green
}
$roleAssignment = @{
    principalId = $testUser
    resourceId = $sp
    appRoleId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
} | ConvertTo-Json
$roleAssignment | Out-File -FilePath "$repoRoot/temp-role.json" -Encoding utf8
az rest --method POST `
    --uri "https://graph.microsoft.com/v1.0/users/$testUser/appRoleAssignments" `
    --headers "Content-Type=application/json" `
    --body "@$repoRoot/temp-role.json" 2>$null | Out-Null
Remove-Item "$repoRoot/temp-role.json" -Force
Write-Host "Role assigned: sample-role-1" -ForegroundColor Green

# ── 6. Verify config files were updated ──

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
