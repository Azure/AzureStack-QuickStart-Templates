##########
# DEPLOY #
##########

# Set Deployment Variables
$RGName = 'myRG001'
$depName = 'myVNDeployment001'

# Deploy vNet Template
New-AzureRmResourceGroupDeployment `
    -Name $depName `
    -ResourceGroupName $RGName `
    -TemplateFile "c:\templates\azuredeploy-vNet.json"