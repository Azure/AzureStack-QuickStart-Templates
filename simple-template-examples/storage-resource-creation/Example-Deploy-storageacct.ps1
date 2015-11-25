##########
# DEPLOY #
##########

# Set Deployment Variables
$storageacct = 'mystorage001'
$RGName = 'myRG001'
$depName = 'mySADeployment001'

# Deploy Storage Account Template
New-AzureRmResourceGroupDeployment `
    -Name $depName `
    -ResourceGroupName $RGName `
    -TemplateFile "c:\templates\azuredeploy-storageacct.json" `
    -newStorageAccountName $storageacct