#Environment Details
$FQDN = Read-Host "Enter External FQDN"
$RegionName = Read-Host "Enter Azure Stack Region Name"
$TenantId = Read-Host "Enter Tenant ID"
$Workfolder = Read-Host "Enter local path that contains templates and artifacts - Example c:\office"

#Deployment Parameters
$StorageAccountName = Read-Host "Enter Name for New Storage Account"
$ResourceGroup = Read-Host "Enter Name for New Resource Group"
$StorageContainerName = Read-Host "Enter Name for Storage Container"
$AdminPassword = Read-Host "Enter Domain Admin Password" -AsSecureString


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


#Deploy AD
New-AzureRmResourceGroupDeployment -Name AD -ResourceGroupName $ResourceGroup -TemplateFile "$Workfolder\templates\ad-ha\azuredeploy.json" -TemplateParameterFile "$Workfolder\templates\ad-ha\azuredeploy.parameters.json" -adminPassword $AdminPassword -storageAccountEndPoint "$RegionName.$FQDN" -diagnosticsStorageAccountName $StorageAccountName -AsJob

#Deploy WAP
$ADJOB=get-job|? name -contains "Long Running Operation for 'New-AzureRmResourceGroupDeployment' on resource 'AD'"
Wait-Job $ADJOB
New-AzureRmResourceGroupDeployment -Name WAP -ResourceGroupName $ResourceGroup -TemplateFile "$Workfolder\templates\wap\azuredeploy.json" -TemplateParameterFile "$Workfolder\templates\wap\azuredeploy.parameters.json" -adminPassword $AdminPassword -storageAccountEndPoint "$RegionName.$FQDN" -diagnosticsStorageAccountName $StorageAccountName -AsJob

#Deploy CA
$ADJOB=get-job|? name -contains "Long Running Operation for 'New-AzureRmResourceGroupDeployment' on resource 'AD'"
Wait-Job $ADJOB
New-AzureRmResourceGroupDeployment -Name CA -ResourceGroupName $ResourceGroup -TemplateFile "$Workfolder\templates\ca\azuredeploy.json" -TemplateParameterFile "$Workfolder\templates\ca\azuredeploy.parameters.json" -adminPassword $AdminPassword -storageAccountEndPoint "$RegionName.$FQDN" -diagnosticsStorageAccountName $StorageAccountName  -AsJob

#Deploy S2D
$ADJOB=get-job|? name -contains "Long Running Operation for 'New-AzureRmResourceGroupDeployment' on resource 'AD'"
Wait-Job $ADJOB
New-AzureRmResourceGroupDeployment -Name S2D -ResourceGroupName $ResourceGroup -TemplateFile "$Workfolder\templates\s2d\azuredeploy.json" -TemplateParameterFile "$Workfolder\templates\s2d\azuredeploy.parameters.json" -adminPassword $AdminPassword -storageAccountEndPoint "$RegionName.$FQDN" -diagnosticsStorageAccountName $StorageAccountName -AsJob

#Deploy Exchange
$S2DJOB=get-job|? name -contains "Long Running Operation for 'New-AzureRmResourceGroupDeployment' on resource 'S2D'"
Wait-Job $S2DJOB
New-AzureRmResourceGroupDeployment -Name MSX -ResourceGroupName $ResourceGroup -TemplateFile "$Workfolder\templates\exchange2016-ha\azuredeploy.json" -TemplateParameterFile "$Workfolder\templates\exchange2016-ha\azuredeploy.parameters.json" -adminPassword $AdminPassword -storageAccountEndPoint "$RegionName.$FQDN" -diagnosticsStorageAccountName $StorageAccountName -AsJob

#Deploy SQL
$S2DJOB=get-job|? name -contains "Long Running Operation for 'New-AzureRmResourceGroupDeployment' on resource 'S2D'"
Wait-Job $S2DJOB
New-AzureRmResourceGroupDeployment -Name SQL -ResourceGroupName $ResourceGroup -TemplateFile "$Workfolder\templates\sql2017-ha\azuredeploy.json" -TemplateParameterFile "$Workfolder\templates\sql2017-ha\azuredeploy.parameters.json" -adminPassword $AdminPassword -storageAccountEndPoint "$RegionName.$FQDN" -diagnosticsStorageAccountName $StorageAccountName -AsJob

#Deploy SP
$SQLJOB=get-job|? name -contains "Long Running Operation for 'New-AzureRmResourceGroupDeployment' on resource 'SQL'"
Wait-Job $SQLJOB
New-AzureRmResourceGroupDeployment -Name SP -ResourceGroupName $ResourceGroup -TemplateFile "$Workfolder\templates\sp2016-ha\azuredeploy.json" -TemplateParameterFile "$Workfolder\templates\sp2016-ha\azuredeploy.parameters.json" -adminPassword $AdminPassword -storageAccountEndPoint "$RegionName.$FQDN" -diagnosticsStorageAccountName $StorageAccountName -AsJob

#Deploy SFB
$SQLJOB=get-job|? name -contains "Long Running Operation for 'New-AzureRmResourceGroupDeployment' on resource 'SQL'"
Wait-Job $SQLJOB
New-AzureRmResourceGroupDeployment -Name SFB -ResourceGroupName $ResourceGroup -TemplateFile "$Workfolder\templates\sfb2015\azuredeploy.json" -TemplateParameterFile "$Workfolder\templates\sfb2015\azuredeploy.parameters.json" -adminPassword $AdminPassword -storageAccountEndPoint "$RegionName.$FQDN" -diagnosticsStorageAccountName $StorageAccountName -AsJob

#Deploy ADFS
$SQLJOB=get-job|? name -contains "Long Running Operation for 'New-AzureRmResourceGroupDeployment' on resource 'SQL'"
Wait-Job $SQLJOB
New-AzureRmResourceGroupDeployment -Name ADFS -ResourceGroupName $ResourceGroup -TemplateFile "$Workfolder\templates\adfs\azuredeploy.json" -TemplateParameterFile "$Workfolder\templates\adfs\azuredeploy.parameters.json" -adminPassword $AdminPassword -diagnosticsStorageAccountName $StorageAccountName -storageAccountEndPoint "$RegionName.$FQDN" -AsJob