# Post-provision hook — deploys content after Bicep creates all resources
# Runs automatically after `azd provision` or `azd up`

$ErrorActionPreference = "Stop"

# All variables come from Bicep outputs (set by azd as env vars)
$resourceGroup     = $env:AZURE_RESOURCE_GROUP
$sqlServerName     = $env:AZURE_SQL_SERVER_NAME
$sqlServerFqdn     = $env:AZURE_SQL_SERVER_FQDN
$sqlDb             = $env:AZURE_SQL_DATABASE
$sqlAdminUser      = $env:AZURE_SQL_ADMIN_USER
$sqlAdminPassword  = $env:AZURE_SQL_ADMIN_PASSWORD
$acrName           = $env:AZURE_ACR_NAME
$webAppName        = $env:AZURE_WEB_APP_NAME
$webUrl            = $env:AZURE_WEB_APP_URL
$dabAppName        = $env:AZURE_CONTAINER_APP_API_NAME
$dabFqdn           = $env:AZURE_CONTAINER_APP_API_FQDN

$sqlConn = "Server=tcp:$sqlServerFqdn,1433;Database=$sqlDb;User Id=$sqlAdminUser;Password=$sqlAdminPassword;Encrypt=true;TrustServerCertificate=false"

# Ensure SqlServer module (Invoke-Sqlcmd) is available
if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    Write-Host "Installing SqlServer module..." -ForegroundColor Yellow
    Install-Module SqlServer -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop | Out-Null
}
Import-Module SqlServer -DisableNameChecking -ErrorAction Stop

# ── 1. Open SQL firewall for local machine ──

Write-Host "Adding client IP to SQL firewall..." -ForegroundColor Yellow
$myIp = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content
az sql server firewall-rule create `
    --resource-group $resourceGroup `
    --server $sqlServerName `
    --name "azd-deploy-client" `
    --start-ip-address $myIp `
    --end-ip-address $myIp 2>$null | Out-Null
Write-Host "Firewall rule added ($myIp)" -ForegroundColor Green

# ── 2. Deploy database schema ──

Write-Host "Deploying schema..." -ForegroundColor Yellow
$schemaSql = Get-Content -Path "database.sql" -Raw
Invoke-Sqlcmd -ConnectionString $sqlConn -Query $schemaSql
Write-Host "Schema deployed" -ForegroundColor Green

# ── 3. Build and push DAB image to ACR ──

Write-Host "Building DAB image in ACR..." -ForegroundColor Yellow
az acr build --registry $acrName --image dab-api:latest --file api/Dockerfile api/ | Out-Null
Write-Host "Image pushed" -ForegroundColor Green

# ── 4. Update DAB container app with custom image ──

Write-Host "Updating DAB container app..." -ForegroundColor Yellow
az containerapp update `
    --name $dabAppName `
    --resource-group $resourceGroup `
    --image "$acrName.azurecr.io/dab-api:latest" | Out-Null
Write-Host "DAB updated" -ForegroundColor Green

# ── 5. Generate config.js and deploy web files ──

Write-Host "Deploying web files..." -ForegroundColor Yellow
$apiUrlAzure = "https://$dabFqdn"

$configContent = @"
const CONFIG = {
    apiUrlLocal: 'http://localhost:5000',
    apiUrlAzure: '$apiUrlAzure'
};
"@

# Write config to temp deploy folder
$deployDir = "web-deploy-temp"
Copy-Item -Path "web" -Destination $deployDir -Recurse -Force
$configContent | Out-File -FilePath "$deployDir/config.js" -Encoding utf8 -Force

Compress-Archive -Path "$deployDir/*" -DestinationPath "web-deploy.zip" -Force
az webapp deploy `
    --resource-group $resourceGroup `
    --name $webAppName `
    --src-path "web-deploy.zip" `
    --type zip | Out-Null
Remove-Item "web-deploy.zip" -Force
Remove-Item $deployDir -Recurse -Force
Write-Host "Web deployed" -ForegroundColor Green

# ── 6. Update local config.js for dev ──

$configContent | Out-File -FilePath "web/config.js" -Encoding utf8 -Force
Write-Host "Local config.js updated" -ForegroundColor Green

# ── Summary ──

Write-Host "`n=== Deployment Complete ===" -ForegroundColor Cyan
Write-Host "Web:           $webUrl" -ForegroundColor White
Write-Host "API:           $apiUrlAzure" -ForegroundColor White
Write-Host "SQL Commander: https://$($env:AZURE_CONTAINER_APP_SQLCMDR_FQDN)" -ForegroundColor White
