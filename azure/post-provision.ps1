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
$dabAppName        = $env:AZURE_CONTAINER_APP_API_NAME
$dabPrincipalId    = $env:AZURE_CONTAINER_APP_API_PRINCIPAL_ID
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
dotnet build database/database.sqlproj
sqlpackage /Action:Publish `
    /SourceFile:database/bin/Debug/database.dacpac `
    /TargetConnectionString:"$sqlConn" `
    /p:BlockOnPossibleDataLoss=false
Write-Host "Schema deployed" -ForegroundColor Green

# ── 3. Grant DAB managed identity access to database ──

Write-Host "Setting Entra admin on SQL Server..." -ForegroundColor Yellow
$currentUser = az ad signed-in-user show --query "{objectId: id, upn: userPrincipalName}" | ConvertFrom-Json
az sql server ad-admin create `
    --resource-group $resourceGroup `
    --server $sqlServerName `
    --display-name $currentUser.upn `
    --object-id $currentUser.objectId | Out-Null
Write-Host "Entra admin set: $($currentUser.upn)" -ForegroundColor Green

Write-Host "Creating database user for DAB managed identity..." -ForegroundColor Yellow
$accessToken = az account get-access-token --resource "https://database.windows.net/" --query accessToken -o tsv
$createUserSql = @"
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = '$dabAppName')
BEGIN
    CREATE USER [$dabAppName] FROM EXTERNAL PROVIDER;
END;
ALTER ROLE db_datareader ADD MEMBER [$dabAppName];
ALTER ROLE db_datawriter ADD MEMBER [$dabAppName];
"@
Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -Database $sqlDb -AccessToken $accessToken -Query $createUserSql
Write-Host "Database user created and granted read/write" -ForegroundColor Green

# ── 4. Build and push DAB image to ACR ──

Write-Host "Building DAB image in ACR..." -ForegroundColor Yellow
az acr build --registry $acrName --image dab-api:latest --file Dockerfile . | Out-Null
Write-Host "Image pushed" -ForegroundColor Green

# ── 5. Update DAB container app with custom image ──

Write-Host "Updating DAB container app..." -ForegroundColor Yellow
az containerapp update `
    --name $dabAppName `
    --resource-group $resourceGroup `
    --image "$acrName.azurecr.io/dab-api:latest" | Out-Null
Write-Host "DAB updated" -ForegroundColor Green

# ── Summary ──

Write-Host "`n=== Deployment Complete ===" -ForegroundColor Cyan
Write-Host "API:           https://$dabFqdn" -ForegroundColor White
Write-Host "SQL Commander: https://$($env:AZURE_CONTAINER_APP_SQLCMDR_FQDN)" -ForegroundColor White
