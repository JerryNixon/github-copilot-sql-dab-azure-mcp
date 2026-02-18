# Azure Teardown Script — Flower Shop
# Deletes the entire resource group and all resources within it

$RG = "flower-shop-rg"

Write-Host "Deleting resource group '$RG' and all resources..." -ForegroundColor Cyan
az group delete --name $RG --yes --no-wait

Write-Host "Deletion started (runs in background). Monitor at https://portal.azure.com" -ForegroundColor Green
