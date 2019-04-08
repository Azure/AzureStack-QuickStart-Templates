#Environment Details
$FQDN = Read-Host "Enter External FQDN"
$RegionName = Read-Host "Enter Azure Stack Region Name"
$TenantId = Read-Host "Enter Tenant ID"
$Workfolder = Read-Host "Enter local path that contains templates and artifacts - Example c:\office"

#Deployment Parameters
$StorageAccountName = Read-Host "Enter Name for New Storage Account"
$ResourceGroup = Read-Host "Enter Name for New Resource Group"
$StorageContainerName = Read-Host "Enter Name for Storage Container"


#Add and Login to Environment
Add-AzureRmEnvironment -Name AzureStack -ARMEndpoint https://management.$RegionName.$FQDN
Login-AzureRmAccount -Environment "AzureStack" -TenantId $TenantId

#Create Resource Group
New-AzureRmResourceGroup -Name $ResourceGroup -Location $RegionName
start-sleep -Seconds 5

#Create Storage Account
New-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroup -Type Standard_LRS -Location $RegionName
$StorageKeys = (Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroup -Name $storageaccountName)[0].Value
$StorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey "$StorageKeys" -Endpoint "$RegionName.$FQDN"
New-AzureStorageContainer -Name $StorageContainerName -Context $StorageContext -Permission Blob

#Upload Artifacts

ls -file $Workfolder\artifacts\ad-ha -Recurse|Set-AzureStorageBlobContent -Container $StorageContainerName -Context $StorageContext -Force
ls -file $Workfolder\artifacts\WAP -Recurse|Set-AzureStorageBlobContent -Container $StorageContainerName -Context $StorageContext -Force
ls -file $Workfolder\artifacts\ca -Recurse|Set-AzureStorageBlobContent -Container $StorageContainerName -Context $StorageContext -Force
ls -file $Workfolder\artifacts\s2d -Recurse|Set-AzureStorageBlobContent -Container $StorageContainerName -Context $StorageContext -Force
ls -file $Workfolder\artifacts\exchange2016-ha -Recurse|Set-AzureStorageBlobContent -Container $StorageContainerName -Context $StorageContext -Force
ls -file $Workfolder\artifacts\sql2017-ha -Recurse|Set-AzureStorageBlobContent -Container $StorageContainerName -Context $StorageContext -Force
ls -file $Workfolder\artifacts\sfb2015 -Recurse|Set-AzureStorageBlobContent -Container $StorageContainerName -Context $StorageContext -Force
ls -file $Workfolder\artifacts\sp2016-ha -Recurse|Set-AzureStorageBlobContent -Container $StorageContainerName -Context $StorageContext -Force
ls -file $Workfolder\artifacts\ADFS -Recurse|Set-AzureStorageBlobContent -Container $StorageContainerName -Context $StorageContext -Force
