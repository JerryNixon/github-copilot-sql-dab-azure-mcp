# Local Development — Flower Shop
# Starts Docker services, builds database project, and deploys schema

docker compose up -d

Write-Host "Building database project..." -ForegroundColor Cyan
dotnet build database\database.sqlproj

Write-Host "Waiting for SQL Server to be healthy..." -ForegroundColor Cyan
do { Start-Sleep -Seconds 2 } while ((docker inspect --format '{{.State.Health.Status}}' sql-2025) -ne 'healthy')

Write-Host "Deploying schema and seed data..." -ForegroundColor Cyan
$pw = if ($env:SA_PASSWORD) { $env:SA_PASSWORD } else { 'YourStrong@Passw0rd' }
sqlpackage /Action:Publish /SourceFile:database\bin\Debug\database.dacpac /TargetConnectionString:"Server=localhost,5000;Database=FlowerShop;User Id=sa;Password=$pw;TrustServerCertificate=true" /p:BlockOnPossibleDataLoss=false

Write-Host "Done! Services running at:" -ForegroundColor Green
Write-Host "  SQL Server:        localhost,5000"
Write-Host "  DAB REST API:      http://localhost:5100/api"
Write-Host "  DAB GraphQL:       http://localhost:5100/graphql"
Write-Host "  SQL Commander:     http://localhost:5200"
Write-Host "  MCP Inspector:     http://localhost:5300/?transport=streamable-http&serverUrl=http%3A%2F%2Fapi-server%3A5000%2Fmcp"
Write-Host "  Health check:      http://localhost:5100/health"
