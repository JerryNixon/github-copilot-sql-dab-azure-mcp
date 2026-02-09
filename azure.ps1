# Azure Deployment Script — Flower Shop
# Run these commands to recreate the Azure deployment from scratch

$RG = "flower-shop-rg"
$LOC = "westus"
$SQL_SERVER = "flower-shop-sql-5723"
$SQL_DB = "FlowerShop"
$SA_PWD = "YourStrong@Passw0rd"
$CAE = "flower-shop-env"
$STORAGE = "flowershopst4754"

# Resource Group
az group create --name $RG --location $LOC

# Azure SQL
az sql server create --name $SQL_SERVER --resource-group $RG --location $LOC --admin-user sqladmin --admin-password $SA_PWD
az sql server firewall-rule create --resource-group $RG --server $SQL_SERVER --name AllowAzureServices --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0
az sql db create --resource-group $RG --server $SQL_SERVER --name $SQL_DB --service-objective S0

# Deploy schema
dotnet build database\database.sqlproj
sqlpackage /Action:Publish /SourceFile:database\bin\Debug\database.dacpac /TargetConnectionString:"Server=tcp:$SQL_SERVER.database.windows.net,1433;Database=$SQL_DB;User Id=sqladmin;Password=$SA_PWD;TrustServerCertificate=true;Encrypt=true" /p:BlockOnPossibleDataLoss=false

# Container Apps
az containerapp env create --name $CAE --resource-group $RG --location $LOC

# Storage for DAB config
az storage account create --name $STORAGE --resource-group $RG --location $LOC --sku Standard_LRS
$STORAGE_KEY = (az storage account keys list --resource-group $RG --account-name $STORAGE --query "[0].value" -o tsv)
az storage share create --name dabconfig --account-name $STORAGE --account-key $STORAGE_KEY
az storage file upload --share-name dabconfig --source dab-config.json --account-name $STORAGE --account-key $STORAGE_KEY
az containerapp env storage set --name $CAE --resource-group $RG --storage-name dabstorage --azure-file-account-name $STORAGE --azure-file-account-key $STORAGE_KEY --azure-file-share-name dabconfig --access-mode ReadOnly

# Deploy DAB
$AZURE_DAB_CONN = "Server=tcp:$SQL_SERVER.database.windows.net,1433;Database=$SQL_DB;User Id=sqladmin;Password=$SA_PWD;TrustServerCertificate=false;Encrypt=true"
az containerapp create --name flower-shop-api --resource-group $RG --environment $CAE --image mcr.microsoft.com/azure-databases/data-api-builder:1.7.83-rc --target-port 5000 --ingress external --env-vars "DATABASE_CONNECTION_STRING=$AZURE_DAB_CONN" --cpu 0.5 --memory 1.0Gi --min-replicas 1 --max-replicas 1
az containerapp update --name flower-shop-api --resource-group $RG --yaml containerapp.yaml
