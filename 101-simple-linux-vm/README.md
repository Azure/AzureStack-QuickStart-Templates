# [IaaS Linux VM]

<a href="http://armviz.io/#/?load=https://raw.githubusercontent.com/Azure/azurestack-quickstart-templates/master/101-simple-linux-vm/azuredeploy.json" target="_blank">
  <img src="http://armviz.io/visualizebutton.png"/>
</a>
This template deploys a simple Linux VM such as ubuntu 14.04, ubuntu 15.10, sles 12 SP1 , CentOS 6.7, CentOS 7.2

`Tags: [Linux, Tag2, Tag3]`

| Endpoint        | Version           | Validated  |
| ------------- |:-------------:| -----:|
| Microsoft Azure Stack      | TP2      |  yes|

## Prerequisites

Follow the below links to create a Linux Image and upload the same to Azure Stack's Platform Image Repository
1. https://azure.microsoft.com/en-us/documentation/articles/azure-stack-linux/ 
2. https://azure.microsoft.com/en-us/documentation/articles/azure-stack-add-image-pir/

## Deployment steps
1. Deploy to azure stack portal using custom deployment.
2. Deploy through Visual Studio using azuredeploy.json and azuredeploy.parameters.json. Note: for other linux versions deployment , rename the *.azuredeploy.parameters.json to the default name before deploying via VisualStudio
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
# Fix the GEN-* values in the azuredeploy.parameters.json before proceeding to next steps
$templateParameterFile= "azuredeploy.parameters.json"
# For Ubuntu 14.04 $templateParameterFile= "ubuntu.14.04.azuredeploy.parameters.json"
# For Suse $templateParameterFile= "suse.12.sp1.azuredeploy.parameters.json"
# For CentOS 6.7 $templateParameterFile= "centos.6.7.azuredeploy.parameters.json"
# For CentOS 7.2 $templateParameterFile= "centos.7.2.azuredeploy.parameters.json"

# Create Resource Group for Template Deployment
New-AzureRmResourceGroup -Name $RGName -Location $myLocation

# Deploy Template 
New-AzureRmResourceGroupDeployment `
    -ResourceGroupName $RGName `
    -TemplateFile $templateFile `
	-TemplateParameterFile $templateParameterFile
```


