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

#Upload SampleCSVFile1.csv to Source Storage Account
$srcStorageAccountContext = New-AzStorageContext -StorageAccountName $srcStorageAccountName -StorageAccountKey (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $srcStorageAccountName)[0].Value
New-AzStorageContainer -Name "data" -Context $srcStorageAccountContext
Set-AzStorageBlobContent -File "SampleCSVFile1.csv" -Container "data" -Blob "SampleCSVFile1.csv" -Context $srcStorageAccountContext

#Create KeyVault
$keyVaultName = "lwscus$($environment)dfcicdkeyvault"
New-AzKeyVault -ResourceGroupName $resourceGroupName -VaultName $keyVaultName -Location $location -Sku Standard

#Get storage account full connection strings and store them in keyvault
$srcStorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $srcStorageAccountName)[0].Value
$destStorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $destStorageAccountName)[0].Value
$srcStorageAccountConnectionString = "DefaultEndpointsProtocol=https;AccountName=$srcStorageAccountName;AccountKey=$srcStorageAccountKey;EndpointSuffix=core.windows.net"
$destStorageAccountConnectionString = "DefaultEndpointsProtocol=https;AccountName=$destStorageAccountName;AccountKey=$destStorageAccountKey;EndpointSuffix=core.windows.net"
$srcStorageAccountConnectionString = ConvertTo-SecureString -String $srcStorageAccountConnectionString -AsPlainText -Force
$destStorageAccountConnectionString = ConvertTo-SecureString -String $destStorageAccountConnectionString -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "srcStorageAccountConnectionString" -SecretValue $srcStorageAccountConnectionString
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "destStorageAccountConnectionString" -SecretValue $destStorageAccountConnectionString

# Create Azure Data Factory
$adfName = "lws-cus-$($environment)-dfcicd-adf"
New-AzDataFactoryV2 -ResourceGroupName $resourceGroupName -Name $adfName -Location $location

# Add Access Policy for Data Factory to access KeyVault
$adfObjectId = (Get-AzDataFactoryV2 -ResourceGroupName $resourceGroupName -Name $adfName).Identity.PrincipalId
Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ObjectId $adfObjectId -PermissionsToSecrets get
