# Deploy Azure resources for Cat Food Manager
# This script creates FREE tier resources only

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [Parameter(Mandatory=$true)]
    [string]$AppName,
    
    [Parameter(Mandatory=$true)]
    [string]$JwtSecret
)

Write-Host "🐱 Cat Food Manager - Azure Deployment" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

# Check if logged in
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "Please login to Azure first..." -ForegroundColor Yellow
    az login
}

Write-Host "`n📦 Creating Resource Group: $ResourceGroupName" -ForegroundColor Green
az group create --name $ResourceGroupName --location $Location

Write-Host "`n🚀 Deploying ARM Template (Free Tier Resources)..." -ForegroundColor Green
az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "azuredeploy.json" `
    --parameters appName=$AppName jwtSecret=$JwtSecret

Write-Host "`n✅ Deployment Complete!" -ForegroundColor Green

$webAppName = "$AppName-api"
$webAppUrl = az webapp show --resource-group $ResourceGroupName --name $webAppName --query defaultHostName -o tsv

Write-Host "`n📱 Your API URL: https://$webAppUrl" -ForegroundColor Cyan
Write-Host "Update this URL in your iOS app's Models.swift file (APIConfig.baseURL)" -ForegroundColor Yellow

Write-Host "`n📝 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Navigate to the backend folder: cd ..\backend\CatFoodManager.API" -ForegroundColor White
Write-Host "2. Publish the app: dotnet publish -c Release" -ForegroundColor White
Write-Host "3. Deploy to Azure: az webapp deploy --resource-group $ResourceGroupName --name $webAppName --src-path bin\Release\net8.0\publish" -ForegroundColor White
