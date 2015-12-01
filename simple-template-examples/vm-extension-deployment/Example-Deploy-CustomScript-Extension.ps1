##########
# DEPLOY #
##########

# Set Deployment Variables
$vmName = 'myVM001'
$RGName = 'myRG001'
$depName = 'myCSDeployment001'

# Deploy Custom Script Template
New-AzureRmResourceGroupDeployment `
    -Name $depName `
    -ResourceGroupName $RGName `
    -TemplateFile "c:\templates\azuredeploy-customscript-command.json" `
    -vmName $vmName