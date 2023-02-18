$subscriptionName = 'LefeWareSolutions-POC'
$location = "centralus"
$environment = "dev"
$resourceGroupName = "lws-cus-$($environment)-dfcicd-rg"



# Connect to Azure 
Connect-AzAccount

# Set Current Subscription Context
$context = Get-AzSubscription -SubscriptionName $subscriptionName
Set-AzContext $context
New-AzResourceGroup -Name $resourceGroupName -Location $location

# Create Storage account
$srcStorageAccountName = "lwscus$($environment)dfcicdstg1"
$destStorageAccountName = "lwscus$($environment)dfcicdstg2"
New-AzStorageAccount -ResourceGroupName $resourceGroupName `
  -Name $srcStorageAccountName `
  -Location $location `
  -SkuName Standard_LRS `
  -Kind StorageV2 `
  -AccessTier Hot
New-AzStorageAccount -ResourceGroupName $resourceGroupName `
  -Name $destStorageAccountName `
  -Location $location `
  -SkuName Standard_LRS `
  -Kind StorageV2 `
  -AccessTier Hot

# Get storage account keys and create a keyvault to store them securely
$srcStorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $srcStorageAccountName)[0].Value
$destStorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $destStorageAccountName)[0].Value
$keyVaultName = "lwscus$($environment)dfcicdkeyvault"
New-AzKeyVault -ResourceGroupName $resourceGroupName -VaultName $keyVaultName -Location $location -Sku Standard
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "srcStorageAccountKey" -SecretValue $srcStorageAccountKey
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "destStorageAccountKey" -SecretValue $destStorageAccountKey

# Create Azure Data Factory
$adfName = "lws-cus-$($environment)-dfcicd-adf"
New-AzDataFactoryV2 -ResourceGroupName $resourceGroupName -Name $adfName -Location $location

# Add Access Policy for Data Factory to access KeyVault
$adfObjectId = (Get-AzDataFactoryV2 -ResourceGroupName $resourceGroupName -Name $adfName).Identity.PrincipalId
Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId $adfObjectId -PermissionsToSecrets get


# Create Azure Data Factory Linked Services for KeyVault and Storage using linked service file 