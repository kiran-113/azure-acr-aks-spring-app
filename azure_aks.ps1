param()

Write-Host "Azure AKS + ACR Deployment Script" -ForegroundColor Cyan

# Step 0: Check Azure CLI login
Write-Host "`nChecking Azure CLI login..." -ForegroundColor Yellow
az account show 1>$null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in. Running az login..." -ForegroundColor Red
    az login
    if ($LASTEXITCODE -ne 0) {
        throw "Azure login failed."
    }
}

# Step 1: Choose or create Resource Group
Write-Host "`nFetching Resource Groups..." -ForegroundColor Cyan
$rgList = az group list --query "[].name" -o tsv

if ($rgList) {
    Write-Host "Available Resource Groups:" -ForegroundColor Green
    $rgList | ForEach-Object { Write-Host " - $_" }
}
$rg = Read-Host "Enter Resource Group name to use or create"

if ($rgList -notcontains $rg) {
    $location = Read-Host "Enter Azure region (e.g., eastus, westus2)"
    Write-Host "Creating Resource Group '$rg' in '$location'..."
    az group create --name $rg --location $location | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create Resource Group."
    }
    Write-Host "Resource Group '$rg' created." -ForegroundColor Green
} else {
    Write-Host "Using existing Resource Group '$rg'." -ForegroundColor Green
}

# Step 2: Create or select AKS cluster
Write-Host "`nFetching AKS clusters in '$rg'..." -ForegroundColor Cyan
$aksList = az aks list --resource-group $rg --query "[].name" -o tsv

if (-not $aksList) {
    Write-Host "No AKS cluster found. Let's create one." -ForegroundColor Yellow
    $aks = Read-Host "Enter new AKS cluster name"
    $nodeCount = Read-Host "Enter number of nodes (default 1)"
    if (-not $nodeCount) { $nodeCount = 1 }
    Write-Host "Creating AKS cluster '$aks'..."
    az aks create --resource-group $rg --name $aks --node-count $nodeCount --enable-managed-identity --generate-ssh-keys | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create AKS cluster."
    }
    Write-Host "AKS cluster '$aks' created." -ForegroundColor Green
} else {
    Write-Host "Available AKS clusters:" -ForegroundColor Green
    $aksList | ForEach-Object { Write-Host " - $_" }
    $aks = Read-Host "Enter AKS cluster name (or leave blank to create new)"
    if (-not $aks) {
        $aks = Read-Host "Enter new AKS cluster name"
        $nodeCount = Read-Host "Enter number of nodes (default 1)"
        if (-not $nodeCount) { $nodeCount = 1 }
        Write-Host "Creating AKS cluster '$aks'..."
        az aks create --resource-group $rg --name $aks --node-count $nodeCount --enable-managed-identity --generate-ssh-keys | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create AKS cluster."
        }
        Write-Host "AKS cluster '$aks' created." -ForegroundColor Green
    } else {
        Write-Host "Using existing AKS cluster '$aks'." -ForegroundColor Green
    }
}

# Step 3: Create or select ACR
Write-Host "`nFetching Azure Container Registries..." -ForegroundColor Cyan
$acrList = az acr list --query "[].name" -o tsv

$acr = Read-Host "Enter ACR name to use or create (Dontuse -)"
if ($acrList -notcontains $acr) {
    # Fetch location from the selected Resource Group
    $rgLocation = az group show --name $rg --query "location" -o tsv
    Write-Host "Creating ACR '$acr' in region '$rgLocation'..."
    az acr create --resource-group $rg --name $acr --sku Basic --location $rgLocation | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create ACR."
    }
    Write-Host "ACR '$acr' created." -ForegroundColor Green
} else {
    Write-Host "Using existing ACR '$acr'." -ForegroundColor Green
}

# Step 4: Link AKS with ACR
Write-Host "`nLinking AKS '$aks' to ACR '$acr'..." -ForegroundColor Cyan
az aks update --name $aks --resource-group $rg --attach-acr $acr | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to attach ACR to AKS."
}
Write-Host "`nSuccessfully linked AKS '$aks' with ACR '$acr'." -ForegroundColor Green

# Step 5: Create Service Principal with Contributor, AcrPush, and AKS roles
Write-Host "`nCreating Service Principal for automation..." -ForegroundColor Cyan
$subId = az account show --query id -o tsv
$spName = "sp-aks-acr-$((Get-Date).ToString('yyyyMMddHHmmss'))"

$spJson = az ad sp create-for-rbac `
    --name $spName `
    --role Contributor `
    --scopes /subscriptions/$subId/resourceGroups/$rg `
    --sdk-auth

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create Service Principal."
}

# Assign ACR Push role at registry level
az role assignment create --assignee (az ad sp list --display-name $spName --query "[0].appId" -o tsv) `
    --role AcrPush `
    --scope (az acr show --name $acr --query id -o tsv) | Out-Null

# Assign AKS Cluster User role
az role assignment create --assignee (az ad sp list --display-name $spName --query "[0].appId" -o tsv) `
    --role "Azure Kubernetes Service Cluster User" `
    --scope (az aks show --resource-group $rg --name $aks --query id -o tsv) | Out-Null

# Save SP credentials JSON
$outFile = Join-Path (Get-Location) "$spName.json"
$spJson | Out-File -Encoding utf8 $outFile
Write-Host "`nService Principal created and saved to: $outFile" -ForegroundColor Green
Write-Host "Use this JSON for GitHub Actions or other automation." -ForegroundColor Green