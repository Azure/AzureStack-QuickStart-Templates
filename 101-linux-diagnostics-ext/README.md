# Deploy Linux Diagnostic extension to an existing Linux VM

This template deploys the Linux Diagnostic Extension to an existing Linux VM in the Azure Stack environment.

Diagnostic Extension can:
•Collects and uploads Linux VM's system performance, diagnostic, and syslog data to user’s storage table.
•Enables user to customize the data metrics that will be collected and uploaded.
•Enables user to upload specified log files to designated storage table

You can read the User Guide for further details - https://github.com/Azure/azure-linux-extensions/tree/master/Diagnostic

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazurestack-quickstart-templates%2Fdevelop%2F101-linux-diagnostics-ext%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazurestack-quickstart-templates%2Fdevelop%2F101-linux-diagnostics-ext%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

`Tags: [Linux, Azurestack, Azure]`

| Endpoint        | Version           | Validated  |
| ------------- |:-------------:| -----:|
| Microsoft Azure Stack      | TP2      |  yes|
| Microsoft Azure      |       |  yes|

## Prerequisites
An existing linux vm in the same resource group

## Deployment Steps 

1. Using Azure CLI

  https://azure.microsoft.com/en-us/documentation/articles/xplat-cli-azure-resource-manager/
 
2. Deploy through portal using custom deployment.

3. Deploy through Visual Studio using azuredeploy.json and azuredeploy.parameters.json. 

4. Using Powershell (https://azure.microsoft.com/en-us/documentation/articles/powershell-azure-resource-manager/)
``` PowerShell
## Configure the environment with the Add-AzureRmEnvironment cmdlt
$endptOut = Invoke-RestMethod "$("https://api.$env:USERDNSDOMAIN".ToLowerInvariant())/metadata/endpoints?api-version=1.0"
$envName = "AzureStackCloud"
Add-AzureRmEnvironment -Name ($envName) `
	                -ActiveDirectoryEndpoint ($ActiveDirectoryEndpoint = $($endptOut.authentication.loginEndpoint) + $($endptOut.authentication.audiences[0]).Split("/")[-1] + "/") `
	                -ActiveDirectoryServiceEndpointResourceId ($ActiveDirectoryServiceEndpointResourceId = $($endptOut.authentication.audiences[0])) `
	                -ResourceManagerEndpoint ($ResourceManagerEndpoint = $("https://api.$env:USERDNSDOMAIN".ToLowerInvariant())) `
	                -GalleryEndpoint ($GalleryEndpoint = $endptOut.galleryEndpoint) `
	                -GraphEndpoint ($GraphEndpoint = $endptOut.graphEndpoint) `
	               -StorageEndpointSuffix ($StorageEndpointSuffix="$($env:USERDNSDOMAIN)".ToLowerInvariant()) `
	               -AzureKeyVaultDnsSuffix ($AzureKeyVaultDnsSuffix="vault.$($env:USERDNSDOMAIN)".ToLowerInvariant()) 
## Authenticate a user to the environment 
    $AADUserName = "Enter_AADUserName"
	$AADUserPassword="Enter_AADUserPassword"
	$aadCredential = New-Object System.Management.Automation.PSCredential($AADUserName, (ConvertTo-SecureString -String $AADUserPassword -AsPlainText -Force))
    $privateEnv = Get-AzureRmEnvironment $envName -Credential $aadCredential
    $privateAzure = Add-AzureRmAccount -Environment $privateEnv -Credential $aadCredential -Verbose
    Select-AzureRmProfile -Profile $privateAzure

## Select an existing subscription where the deployment will take place
    Get-AzureRmSubscription -SubscriptionName "SUBSCRIPTION_NAME"  | Select-AzureRmSubscription


# Set Deployment Variables
$myNum = "001" #Modify this per deployment
$RGName = "myRG$myNum"
$myLocation = "local"

$templateFile= "azuredeploy.json"
$templateParameterFile= "azuredeploy.parameters.json"

# Create Resource Group for Template Deployment
New-AzureRmResourceGroup -Name $RGName -Location $myLocation

# Deploy Template 
New-AzureRmResourceGroupDeployment `
    -ResourceGroupName $RGName `
    -TemplateFile $templateFile `
	-TemplateParameterFile $templateParameterFile
```

