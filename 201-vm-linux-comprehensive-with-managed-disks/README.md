# [IaaS Linux VM Comprehensive Resources]

This template deploys a Linux VM and also uses Customscript and OSPatchingforLinux Extensions. The VM is set with 2 managed disks; the OS disk and a data disk of 1 GB.

## Prerequisites

Follow the below links to download/create an Ubuntu 14.04.3-LTS Image and upload the same to Azure Stack's Platform Image Repository(PIR)
1. https://azure.microsoft.com/en-us/documentation/articles/azure-stack-linux/ 
2. https://azure.microsoft.com/en-us/documentation/articles/azure-stack-add-image-pir/
	Note: please use the default values for linuxPublisher,linuxOffer,linuxSku,linuxVersion found in azuredeploy.json while creating the manifest.json in PIR

## Deployment steps
1. Deploy to azure stack portal using custom deployment.
2. Deploy through Visual Studio using azuredeploy.json and azuredeploy.parameters.json.
2. Deploy the solution from PowerShell with the following PowerShell script 

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


