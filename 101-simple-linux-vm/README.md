# [IaaS Linux VM]

<a href="http://armviz.io/#/?load=https://raw.githubusercontent.com/Azure/azurestack-quickstart-templates/master/101-simple-linux-vm/azuredeploy.json" target="_blank">
  <img src="http://armviz.io/visualizebutton.png"/>
</a>
This template deploys a simple Linux VM such as ubuntu 15.10, sles 12 SP1 , CentOS 67

`Tags: [Tag1, Tag2, Tag3]`

| Endpoint        | Version           | Validated  |
| ------------- |:-------------:| -----:|
| Microsoft Azure Stack      | TP1      |  yes|

## Prerequisites

Follow the below links to create a Linux Image and upload the same to Azure Stack's Platform Image Repository
1. https://azure.microsoft.com/en-us/documentation/articles/azure-stack-linux/ 
2. https://azure.microsoft.com/en-us/documentation/articles/azure-stack-add-image-pir/

## Deployment steps
1. Deploy to azure stack portal using custom deployment.
2. Deploy through Visual Studio using azuredeploy.json and azuredeploy.parameters.json. Note: for other linux versions deployment , rename the *.azuredeploy.parameters.json to the default name before deploying via VisualStudio
2. Deploy the solution from PowerShell with the following PowerShell script 

``` PowerShell
## Specify your AzureAD Tenant in a variable. 
# If you know the prefix of your <prefix>.onmicrosoft.com AzureAD account use option 1)
# If you do not know the prefix of your <prefix>.onmicrosoft.com AzureAD account use option 2)

# Option 1) If you know the prefix of your <prefix>.onmicrosoft.com AzureAD namespace.
# You need to set that in the $AadTenantId varibale (e.g. contoso.onmicrosoft.com).
    $AadTenantId = "contoso"

# Option 2) If you don't know the prefix of your AzureAD namespace, run the following cmdlets. 
# Validate with the Azure AD credentials you also use to sign in as a tenant to Microsoft Azure Stack Technical Preview.
    $AadTenant = Login-AzureRmAccount
    $AadTenantId = $AadTenant.Context.Tenant.TenantId

## Configure the environment with the Add-AzureRmEnvironment cmdlt
    Add-AzureRmEnvironment -Name 'Azure Stack' `
        -ActiveDirectoryEndpoint ("https://login.windows.net/$AadTenantId/") `
        -ActiveDirectoryServiceEndpointResourceId "https://azurestack.local-api/"`
        -ResourceManagerEndpoint ("https://api.azurestack.local/") `
        -GalleryEndpoint ("https://gallery.azurestack.local/") `
        -GraphEndpoint "https://graph.windows.net/"

## Authenticate a user to the environment (you will be prompted during authentication)
    $privateEnv = Get-AzureRmEnvironment 'Azure Stack'
    $privateAzure = Add-AzureRmAccount -Environment $privateEnv -Verbose
    Select-AzureRmProfile -Profile $privateAzure

## Select an existing subscription where the deployment will take place
    Get-AzureRmSubscription -SubscriptionName "SUBSCRIPTION_NAME"  | Select-AzureRmSubscription

# Set Deployment Variables
$myNum = "001" #Modify this per deployment
$RGName = "myRG$myNum"
$myLocation = "local"

$templateFile= "azuredeploy.json"
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


