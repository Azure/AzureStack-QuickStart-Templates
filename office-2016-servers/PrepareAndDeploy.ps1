#Environment Details
$FQDN = Read-Host "Enter External FQDN"
$RegionName = Read-Host "Enter Azure Stack Region Name"
$TenantId = Read-Host "Enter Tenant ID"

#Deployment Parameters
$StorageAccountName = Read-Host "Enter Name for New Storage Account"
$ResourceGroup = Read-Host "Enter Name for New Resource Group"
$StorageContainerName = Read-Host "Enter Name for Storage Container"
$Credential = Read-Host "Enter Domain Admin Password" -AsSecureString


#Add and Login to Environment
Add-AzureRmEnvironment -Name AzureStack -ARMEndpoint https://management.$RegionName.$FQDN
Login-AzureRmAccount -Environment "AzureStack" -TenantId $TenantId

#Create Resource Group
New-AzureRmResourceGroup -Name $ResourceGroup -Location $RegionName 
start-sleep -Seconds 5

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
New-AzureRmResourceGroupDeployment -Name AD -ResourceGroupName $ResourceGroup -TemplateFile .\templates\ad-ha\azuredeploy.json -TemplateParameterFile .\templates\ad-ha\azuredeploy.parameters.json -adminPassword $AdminPassword -AsJob

#Deploy CA
$ADJOB=get-job|? name -contains "Long Running Operation for 'New-AzureRmResourceGroupDeployment' on resource 'AD'"
Wait-Job $ADJOB
New-AzureRmResourceGroupDeployment -Name CA -ResourceGroupName $ResourceGroup -TemplateFile .\templates\ca\azuredeploy.json -TemplateParameterFile .\templates\ca\azuredeploy.parameters.json -adminPassword $AdminPassword -AsJob

#Deploy S2D
$ADJOB=get-job|? name -contains "Long Running Operation for 'New-AzureRmResourceGroupDeployment' on resource 'AD'"
Wait-Job $ADJOB
New-AzureRmResourceGroupDeployment -Name S2D -ResourceGroupName $ResourceGroup -TemplateFile .\templates\s2d\azuredeploy.json -TemplateParameterFile .\templates\s2d\azuredeploy.parameters.json -adminPassword $AdminPassword -AsJob

#Deploy Exchange
$S2DJOB=get-job|? name -contains "Long Running Operation for 'New-AzureRmResourceGroupDeployment' on resource 'S2D'"
Wait-Job $S2DJOB
New-AzureRmResourceGroupDeployment -Name MSX -ResourceGroupName $ResourceGroup -TemplateFile .\templates\exchange2016-ha\azuredeploy.json -TemplateParameterFile .\templates\exchange2016-ha\azuredeploy.parameters.json -adminPassword $AdminPassword -AsJob

#Deploy SQL
$S2DJOB=get-job|? name -contains "Long Running Operation for 'New-AzureRmResourceGroupDeployment' on resource 'S2D'"
Wait-Job $S2DJOB
New-AzureRmResourceGroupDeployment -Name SQL -ResourceGroupName $ResourceGroup -TemplateFile .\templates\sql2017-ha\azuredeploy.json -TemplateParameterFile .\templates\sql2017-ha\azuredeploy.parameters.json -adminPassword $AdminPassword -AsJob

#Deploy SFB
$SQLJOB=get-job|? name -contains "Long Running Operation for 'New-AzureRmResourceGroupDeployment' on resource 'SQL'"
Wait-Job $SQLJOB
New-AzureRmResourceGroupDeployment -Name SFB -ResourceGroupName $ResourceGroup -TemplateFile .\templates\sfb2015\azuredeploy.json -TemplateParameterFile .\templates\sfb2015\azuredeploy.parameters.json -adminPassword $AdminPassword -AsJob