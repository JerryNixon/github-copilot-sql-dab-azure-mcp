# Azure Deployment Script — Flower Shop
# Uses custom Docker image with embedded dab-config.json (NO storage accounts)

$RG = "flower-shop-rg2"
$LOC = "westus"
$SQL_SERVER = "flower-shop-sql-8291"
$SQL_DB = "FlowerShop"
$SA_PWD = "YourStrong@Passw0rd"
$CAE = "flower-shop-env"
$ACR = "flowershopcr8291"

# Resource Group
az group create --name $RG --location $LOC

# Azure SQL
az sql server create --name $SQL_SERVER --resource-group $RG --location $LOC --admin-user sqladmin --admin-password $SA_PWD
az sql server firewall-rule create --resource-group $RG --server $SQL_SERVER --name AllowAzureServices --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0
az sql db create --resource-group $RG --server $SQL_SERVER --name $SQL_DB --service-objective S0

# Deploy schema
dotnet build database\database.sqlproj
sqlpackage /Action:Publish /SourceFile:database\bin\Debug\database.dacpac /TargetConnectionString:"Server=tcp:$SQL_SERVER.database.windows.net,1433;Database=$SQL_DB;User Id=sqladmin;Password=$SA_PWD;TrustServerCertificate=true;Encrypt=true" /p:BlockOnPossibleDataLoss=false

# Azure Container Registry (custom image with embedded config)
az acr create --name $ACR --resource-group $RG --sku Basic --admin-enabled true
az acr build --registry $ACR --image dab-api:latest .

# Container Apps
az containerapp env create --name $CAE --resource-group $RG --location $LOC

# Deploy DAB (custom image from ACR)
$AZURE_DAB_CONN = "Server=tcp:$SQL_SERVER.database.windows.net,1433;Database=$SQL_DB;User Id=sqladmin;Password=$SA_PWD;TrustServerCertificate=false;Encrypt=true"
$ACR_PWD = (az acr credential show --name $ACR --query "passwords[0].value" -o tsv)
az containerapp create --name flower-shop-api --resource-group $RG --environment $CAE --image "$ACR.azurecr.io/dab-api:latest" --registry-server "$ACR.azurecr.io" --registry-username $ACR --registry-password $ACR_PWD --target-port 5000 --ingress external --secrets "db-conn=$AZURE_DAB_CONN" --env-vars "DATABASE_CONNECTION_STRING=secretref:db-conn" --cpu 0.5 --memory 1.0Gi --min-replicas 1 --max-replicas 1
