##########
# DEPLOY #
##########

# Set Deployment Variables
$vmName = 'myVM001'
$RGName = 'myRG001'
$depName = 'myBGIDeployment001'

# Deploy BGInfo Template
New-AzureRmResourceGroupDeployment `
    -Name $depName `
    -ResourceGroupName $RGName `
    -TemplateFile "c:\templates\azuredeploy-bginfo.json" `
    -vmName $vmName