# Post-down hook — cleans up Entra ID resources after `azd down`
# App registrations are tenant-level and not deleted by `azd down`

$ErrorActionPreference = "Stop"

$envName = $env:AZURE_ENV_NAME
$appName = "app-$envName"

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

$domainName = az ad signed-in-user show --query 'userPrincipalName' -o tsv | ForEach-Object { $_.Split('@')[1] }
$testUserPrincipal = "testuser-$envName@$domainName"
$existingUser = az ad user list --filter "userPrincipalName eq '$testUserPrincipal'" --query "[0].id" -o tsv

if ($existingUser) {
    az ad user delete --id $existingUser
    Write-Host "Deleted test user: $testUserPrincipal" -ForegroundColor Green
} else {
    Write-Host "No test user found: $testUserPrincipal" -ForegroundColor Gray
}

Write-Host "Entra ID cleanup complete." -ForegroundColor Cyan
