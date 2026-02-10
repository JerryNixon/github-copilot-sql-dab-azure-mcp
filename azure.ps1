# Azure Setup Script - Idempotent
# Creates resource group and app registration for Entra ID authentication

$ErrorActionPreference = "Stop"

# Configuration
$resourceGroupName = "rg-todo-app"
$location = "eastus"
$appName = "todo-app"
$redirectUri = "http://localhost:5173"
$testUserName = "todo-testuser"
$testUserPassword = "TodoTest123!"

Write-Host "=== Azure Todo App Setup ===" -ForegroundColor Cyan

# 1. Create Resource Group (idempotent)
Write-Host "`nChecking resource group..." -ForegroundColor Yellow
$rg = az group exists --name $resourceGroupName

if ($rg -eq "false") {
    Write-Host "Creating resource group: $resourceGroupName" -ForegroundColor Green
    az group create --name $resourceGroupName --location $location | Out-Null
    Write-Host "Resource group created" -ForegroundColor Green
} else {
    Write-Host "Resource group already exists" -ForegroundColor Gray
}

# 2. Create App Registration (idempotent)
Write-Host "`nChecking app registration..." -ForegroundColor Yellow
$appJson = az ad app list --display-name $appName --query "[0]"
$app = $appJson | ConvertFrom-Json

if ($appJson -eq "null" -or -not $app) {
    Write-Host "Creating app registration: $appName" -ForegroundColor Green
    
    # Create app first
    $app = az ad app create `
        --display-name $appName `
        --sign-in-audience "AzureADMyOrg" `
        --query "{appId: appId, id: id}" | ConvertFrom-Json
    
    # Configure as SPA using Graph API
    $spaConfig = @{
        spa = @{
            redirectUris = @($redirectUri)
        }
    } | ConvertTo-Json -Depth 3
    
    $spaConfig | Out-File -FilePath "temp-spa-config.json" -Encoding utf8
    az rest --method PATCH --uri "https://graph.microsoft.com/v1.0/applications/$($app.id)" --headers "Content-Type=application/json" --body "@temp-spa-config.json" | Out-Null
    Remove-Item "temp-spa-config.json" -Force
    
    Write-Host "App registration created as SPA" -ForegroundColor Green
} else {
    Write-Host "App registration already exists" -ForegroundColor Gray
    
    # Ensure it's configured as SPA (idempotent)
    $spaConfig = @{
        spa = @{
            redirectUris = @($redirectUri)
        }
        web = @{
            redirectUris = @()
        }
    } | ConvertTo-Json -Depth 3
    
    $spaConfig | Out-File -FilePath "temp-spa-config.json" -Encoding utf8
    az rest --method PATCH --uri "https://graph.microsoft.com/v1.0/applications/$($app.id)" --headers "Content-Type=application/json" --body "@temp-spa-config.json" | Out-Null
    Remove-Item "temp-spa-config.json" -Force
}

# 3. Get Tenant ID
$tenantId = az account show --query tenantId -o tsv
$domainName = az ad signed-in-user show --query 'userPrincipalName' -o tsv | ForEach-Object { $_.Split('@')[1] }

# 4. Create Test User (idempotent)
Write-Host "`nChecking test user..." -ForegroundColor Yellow
$testUserPrincipal = "$testUserName@$domainName"
$existingUser = az ad user list --filter "userPrincipalName eq '$testUserPrincipal'" --query "[0]" | ConvertFrom-Json

if (-not $existingUser) {
    Write-Host "Creating test user: $testUserPrincipal" -ForegroundColor Green
    az ad user create `
        --display-name "Todo Test User" `
        --user-principal-name $testUserPrincipal `
        --password $testUserPassword `
        --force-change-password-next-sign-in false | Out-Null
    Write-Host "Test user created" -ForegroundColor Green
} else {
    Write-Host "Test user already exists" -ForegroundColor Gray
}

# 5. Update .env file
Write-Host "`nUpdating .env file..." -ForegroundColor Yellow
$envPath = ".env"

# Read existing .env or create new content
if (Test-Path $envPath) {
    $envContent = Get-Content $envPath -Raw
} else {
    $envContent = ""
}

# Update or add Entra ID values
if ($envContent -match "ENTRA_CLIENT_ID=") {
    $envContent = $envContent -replace "ENTRA_CLIENT_ID=.*", "ENTRA_CLIENT_ID=$($app.appId)"
} else {
    $envContent += "`nENTRA_CLIENT_ID=$($app.appId)"
}

if ($envContent -match "ENTRA_TENANT_ID=") {
    $envContent = $envContent -replace "ENTRA_TENANT_ID=.*", "ENTRA_TENANT_ID=$tenantId"
} else {
    $envContent += "`nENTRA_TENANT_ID=$tenantId"
}

if ($envContent -match "ENTRA_REDIRECT_URI=") {
    $envContent = $envContent -replace "ENTRA_REDIRECT_URI=.*", "ENTRA_REDIRECT_URI=$redirectUri"
} else {
    $envContent += "`nENTRA_REDIRECT_URI=$redirectUri"
}

$envContent | Set-Content $envPath -NoNewline
Write-Host ".env file updated" -ForegroundColor Green

# 6. Display summary
Write-Host "`n=== Setup Complete ===" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroupName" -ForegroundColor White
Write-Host "App Name: $appName" -ForegroundColor White
Write-Host "Client ID: $($app.appId)" -ForegroundColor White
Write-Host "Tenant ID: $tenantId" -ForegroundColor White
Write-Host "Redirect URI: $redirectUri" -ForegroundColor White
Write-Host "`nTest User Credentials:" -ForegroundColor Cyan
Write-Host "Username: $testUserPrincipal" -ForegroundColor White
Write-Host "Password: $testUserPassword" -ForegroundColor White
Write-Host "`nIMPORTANT: Update hardcoded values in web/index.html:" -ForegroundColor Yellow
Write-Host "  clientId: '$($app.appId)'" -ForegroundColor White
Write-Host "  authority: 'https://login.microsoftonline.com/$tenantId'" -ForegroundColor White



