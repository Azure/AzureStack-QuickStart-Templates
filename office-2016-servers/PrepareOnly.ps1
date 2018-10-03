#Environment Details.PLEASE ADJUST 
$FQDN = "azurestack.corp.microsoft.com"
$RegionName = "orlando"
$StorageAccountName = "trval"
$ResourceGroup = "valirg"
$StorageContainerName = "workload"
$TenantId = "246b1785-9030-40d8-a0f0-d94b15dc002c"


#Add and Login to Environment
Add-AzureRmEnvironment -Name AzureStack -ARMEndpoint https://management.$RegionName.$FQDN
Login-AzureRmAccount -Environment "AzureStack" -TenantId $TenantId

#Create Resource Group
New-AzureRmResourceGroup -Name $ResourceGroup -Location $RegionName 

#Create Storage Account
New-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroup -Type Standard_LRS -Location $RegionName
$StorageKeys = Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroup -Name $StorageAccountName
$StorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageKeys.Key1 -Endpoint "$RegionName.$FQDN"
New-AzureStorageContainer -Name $StorageContainerName -Context $StorageContext -Permission Blob

#Upload Artifacts

ls -file .\artifacts\ad-ha -Recurse|Set-AzureStorageBlobContent -Container $StorageContainerName -Context $StorageContext -Force
ls -file .\artifacts\ca -Recurse|Set-AzureStorageBlobContent -Container $StorageContainerName -Context $StorageContext -Force
ls -file .\artifacts\s2d -Recurse|Set-AzureStorageBlobContent -Container $StorageContainerName -Context $StorageContext -Force
ls -file .\artifacts\exchange2016-ha -Recurse|Set-AzureStorageBlobContent -Container $StorageContainerName -Context $StorageContext -Force
ls -file .\artifacts\sql2017-ha -Recurse|Set-AzureStorageBlobContent -Container $StorageContainerName -Context $StorageContext -Force
ls -file .\artifacts\sfb2015 -Recurse|Set-AzureStorageBlobContent -Container $StorageContainerName -Context $StorageContext -Force
