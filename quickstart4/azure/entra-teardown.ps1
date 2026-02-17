# Post-down hook — cleans up Entra ID resources after `azd down`
# App registrations are tenant-level and not deleted by `azd down`

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path "$PSScriptRoot/..").Path
$azureEnvFile = "$repoRoot/.azure-env"

if (-not (Test-Path $azureEnvFile)) {
    Write-Host "No .azure-env file found — nothing to clean up." -ForegroundColor Gray
    exit 0
}

# Read .azure-env
$envData = @{}
Get-Content $azureEnvFile | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
    $parts = $_ -split '=', 2
    $envData[$parts[0].Trim()] = $parts[1].Trim()
}

$appName = $envData['app-registration']
$testUserPrincipal = $envData['username']

# ── 1. Delete app registration ──

Write-Host "Cleaning up Entra ID app registration..." -ForegroundColor Yellow
$app = az ad app list --display-name $appName --query "[0].{appId: appId, id: id}" | ConvertFrom-Json

if ($app) {
    az ad app delete --id $app.id
    Write-Host "Deleted app registration: $appName" -ForegroundColor Green
} else {
    Write-Host "No app registration found: $appName" -ForegroundColor Gray
}

# ── 2. Delete test user ──

if ($testUserPrincipal) {
    $existingUser = az ad user list --filter "userPrincipalName eq '$testUserPrincipal'" --query "[0].id" -o tsv
    if ($existingUser) {
        az ad user delete --id $existingUser
        Write-Host "Deleted test user: $testUserPrincipal" -ForegroundColor Green
    } else {
        Write-Host "No test user found: $testUserPrincipal" -ForegroundColor Gray
    }
}

# ── 3. Reset config files to placeholder state ──

Write-Host "Resetting config files..." -ForegroundColor Yellow

@"
const CONFIG = {
    clientId: '__CLIENT_ID__',
    tenantId: '__TENANT_ID__',
    apiUrlLocal: 'http://localhost:5000',
    apiUrlAzure: '__API_URL_AZURE__'
};
"@ | Out-File -FilePath "$repoRoot/web/config.js" -Encoding utf8 -Force

Push-Location "$repoRoot/api"
dab configure `
    --runtime.host.authentication.provider "EntraId" `
    --runtime.host.authentication.jwt.audience "__AUDIENCE__" `
    --runtime.host.authentication.jwt.issuer "__ISSUER__"
Pop-Location

Write-Host "Config files reset to placeholders" -ForegroundColor Green

# ── 4. Delete .azure-env ──

Remove-Item $azureEnvFile -Force
Write-Host "Deleted .azure-env" -ForegroundColor Green

Write-Host "Entra ID cleanup complete." -ForegroundColor Cyan
