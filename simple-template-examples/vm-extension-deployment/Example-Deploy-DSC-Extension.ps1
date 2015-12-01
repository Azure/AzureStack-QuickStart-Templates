##########
# DEPLOY #
##########

# Set Deployment Variables
$vmName = 'myVM001'
$RGName = 'myRG001'
$depName = 'myDSCDeployment001'

# Deploy DSC Extension Template
New-AzureRmResourceGroupDeployment `
    -Name $depName `
    -ResourceGroupName $RGName `
    -TemplateFile "c:\templates\azuredeploy-dsc.json" `
    -TemplateParameterFile "C:\templates\azuredeploy-dsc.parameters.json" `
    -vmName $vmName `
    -timestamp (Get-Date)