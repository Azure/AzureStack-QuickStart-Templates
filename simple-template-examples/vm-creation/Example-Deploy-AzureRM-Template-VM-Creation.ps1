##########
# DEPLOY #
##########

# Set Deployment Variables
$myNum = "001" #Modify this per deployment
$RGName = "myRG$myNum"
$myLocation = "local"
$myBlobStorageEndpoint = "blob.azurestack.local"

# Create Resource Group for Template Deployment
New-AzureRMResourceGroup -Name $RGName -Location $myLocation

# Deploy Simple IaaS Template 
New-AzureRmResourceGroupDeployment `
    -Name "myDeploymen$myNum" `
    -ResourceGroupName $RGName `
    -TemplateFile "c:\templates\azuredeploy-101-simple-windows-vm-withDNS.json" `
    -deploymentLocation $myLocation `
    -blobStorageEndpoint $myBlobStorageEndpoint `
    -newStorageAccountName "mystorage$myNum" `
    -dnsNameForPublicIP "mydns$myNum" `
    -adminUsername "admin" `
    -adminPassword ("User@123" | ConvertTo-SecureString -AsPlainText -Force) `
    -vmName "myVM$myNum" `
    -windowsOSVersion "2012-R2-Datacenter"