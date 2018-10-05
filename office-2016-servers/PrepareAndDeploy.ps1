#Environment Details. PLEASE ADJUST
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


#Deploy AD
New-AzureRmResourceGroupDeployment -Name AD -ResourceGroupName $ResourceGroup -TemplateFile .\templates\ad-ha\azuredeploy.json -TemplateParameterFile .\templates\ad-ha\azuredeploy.parameters.json

#Deploy CA
New-AzureRmResourceGroupDeployment -Name CA -ResourceGroupName $ResourceGroup -TemplateFile .\templates\ca\azuredeploy.json -TemplateParameterFile .\templates\ca\azuredeploy.parameters.json

#Deploy S2D
New-AzureRmResourceGroupDeployment -Name S2D -ResourceGroupName $ResourceGroup -TemplateFile .\templates\s2d\azuredeploy.json -TemplateParameterFile .\templates\s2d\azuredeploy.parameters.json

#Deploy Exchange
New-AzureRmResourceGroupDeployment -Name MSX -ResourceGroupName $ResourceGroup -TemplateFile .\templates\exchange2016-ha\azuredeploy.json -TemplateParameterFile .\templates\exchange2016-ha\azuredeploy.parameters.json

#Deploy SQL
New-AzureRmResourceGroupDeployment -Name SQL -ResourceGroupName $ResourceGroup -TemplateFile .\templates\sql2017-ha\azuredeploy.json -TemplateParameterFile .\templates\sql2017-ha\azuredeploy.parameters.json

#Deploy SFB
New-AzureRmResourceGroupDeployment -Name SFB -ResourceGroupName $ResourceGroup -TemplateFile .\templates\sfb2015\azuredeploy.json -TemplateParameterFile .\templates\sfb2015\azuredeploy.parameters.json