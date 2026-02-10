# Local Development Setup
# Deploys database schema and starts Data API Builder locally

$ErrorActionPreference = "Stop"

Write-Host "=== Local TODO App Setup ===" -ForegroundColor Cyan

# Configuration
$sqlServer = "localhost"
$sqlDatabase = "TodoDb"
$sqlUser = "sa"
$sqlPassword = "YourStrong@Passw0rd"
$dabPort = 5000

# 1. Check if SQL Server is running
Write-Host "`nChecking SQL Server connection..." -ForegroundColor Yellow

try {
    # Test connection without specifying database (connects to default/master)
    sqlcmd -S $sqlServer -U $sqlUser -P $sqlPassword -Q "SELECT 1" -b | Out-Null
    Write-Host "SQL Server is running" -ForegroundColor Green
} catch {
    Write-Host "ERROR: SQL Server not accessible at $sqlServer" -ForegroundColor Red
    Write-Host "Please start SQL Server (Docker, LocalDB, or SQL Server Express)" -ForegroundColor Yellow
    Write-Host "`nExample Docker command:" -ForegroundColor Cyan
    Write-Host "docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=$sqlPassword' -p 1433:1433 -d mcr.microsoft.com/mssql/server:2022-latest" -ForegroundColor White
    exit 1
}

# 2. Deploy database schema
Write-Host "`nDeploying database schema..." -ForegroundColor Yellow
$dacpacPath = "database\bin\Debug\database.dacpac"

if (-not (Test-Path $dacpacPath)) {
    Write-Host "Building database project..." -ForegroundColor Yellow
    dotnet build database/database.sqlproj | Out-Null
}

$targetConnectionString = "Server=$sqlServer;Database=$sqlDatabase;User Id=$sqlUser;Password=$sqlPassword;TrustServerCertificate=True"

sqlpackage /Action:Publish `
    /SourceFile:$dacpacPath `
    /TargetConnectionString:$targetConnectionString `
    /p:BlockOnPossibleDataLoss=false | Out-Null

Write-Host "Database deployed with sample data" -ForegroundColor Green

# 3. Update .env with connection string
Write-Host "`nUpdating .env file..." -ForegroundColor Yellow
$envPath = ".env"
$dabConnectionString = "Server=$sqlServer;Database=$sqlDatabase;User Id=$sqlUser;Password=$sqlPassword;TrustServerCertificate=True"

if (Test-Path $envPath) {
    $envContent = Get-Content $envPath -Raw
    if ($envContent -match "DATABASE_CONNECTION_STRING=") {
        $envContent = $envContent -replace "DATABASE_CONNECTION_STRING=.*", "DATABASE_CONNECTION_STRING=$dabConnectionString"
    } else {
        $envContent += "`nDATABASE_CONNECTION_STRING=$dabConnectionString"
    }
} else {
    $envContent = "DATABASE_CONNECTION_STRING=$dabConnectionString"
}

$envContent | Set-Content $envPath -NoNewline
Write-Host ".env file updated" -ForegroundColor Green

# 4. Install DAB CLI if not installed
Write-Host "`nChecking Data API Builder CLI..." -ForegroundColor Yellow
$dabInstalled = dotnet tool list -g | Select-String "microsoft.dataapibuilder"

if (-not $dabInstalled) {
    Write-Host "Installing Data API Builder CLI..." -ForegroundColor Yellow
    dotnet tool install -g Microsoft.DataApiBuilder --version 1.2.10
    Write-Host "DAB CLI installed" -ForegroundColor Green
} else {
    Write-Host "DAB CLI already installed" -ForegroundColor Gray
}

# 5. Initialize DAB config if not exists
Write-Host "`nConfiguring Data API Builder..." -ForegroundColor Yellow
if (-not (Test-Path "dab-config.json")) {
    dab init --database-type "mssql" `
        --connection-string "@env('DATABASE_CONNECTION_STRING')" `
        --host-mode "Development" `
        --cors-origin "http://localhost:5173"
    
    # Add Todos entity
    dab add Todos --source "dbo.Todos" --permissions "anonymous:*"
    
    Write-Host "DAB configuration created" -ForegroundColor Green
} else {
    Write-Host "DAB configuration already exists" -ForegroundColor Gray
}

# 6. Display next steps
Write-Host "`n=== Setup Complete ===" -ForegroundColor Cyan
Write-Host "Database: $sqlDatabase on $sqlServer" -ForegroundColor White
Write-Host "DAB Config: dab-config.json" -ForegroundColor White
Write-Host "`nTo start services:" -ForegroundColor Cyan
Write-Host "  Terminal 1: dab start" -ForegroundColor White
Write-Host "  Terminal 2: cd web; python -m http.server 5173" -ForegroundColor White
Write-Host "`nAPI: http://localhost:${dabPort}/api/Todos" -ForegroundColor White
Write-Host "Web: http://localhost:5173" -ForegroundColor White
