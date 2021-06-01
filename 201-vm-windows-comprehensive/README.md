# [IaaS VM Comprehensive Resources]

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazurestack-quickstart-templates%2Fmaster%2F201-Comprehensive%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https://raw.githubusercontent.com/Azure/azurestack-quickstart-templates/master/201-Comprehensive/azuredeploy.json" target="_blank">
  <img src="http://armviz.io/visualizebutton.png"/>
</a>

This template deploys a [solution name]. The [solution name] is a [description]

`Tags: [Tag1, Tag2, Tag3]`

| Endpoint        | Version           | Validated  |
| ------------- |:-------------:| -----:|
| Microsoft Azure      | - | no |
| Microsoft Azure Stack      |       |  no |

## Prerequisites

[Decscription of the prerequistes for the deployment]

## Deployment steps
You can either click the "deploy to Azure" button at the beginning of this document or deploy the solution from PowerShell with the following PowerShell script.

``` PowerShell
## Specify your AzureAD Tenant in a variable.
# If you know the prefix of your <prefix>.onmicrosoft.com AzureAD account use option 1)
# If you do not know the prefix of your <prefix>.onmicrosoft.com AzureAD account use option 2)

# Option 1) If you know the prefix of your <prefix>.onmicrosoft.com AzureAD namespace.
# You need to set that in the $AadTenantId varibale (e.g. contoso.onmicrosoft.com).
    $AadTenantId = "contoso"

# Option 2) If you don't know the prefix of your AzureAD namespace, run the following cmdlets.
# Validate with the Azure AD credentials you also use to sign in as a tenant to Microsoft Azure Stack Development Kit.
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
$myBlobStorageEndpoint = "blob.azurestack.local"

# Create Resource Group for Template Deployment
New-AzureRmResourceGroup -Name $RGName -Location $myLocation

# Deploy Template
New-AzureRmResourceGroupDeployment `
    -Name "myDeployment$myNum" `
    -ResourceGroupName $RGName `
    -TemplateFile "c:\templates\azuredeploy-101-simple-windows-vm-withDNS.json" `
    -blobStorageEndpoint $myBlobStorageEndpoint `
    -newStorageAccountName "mystorage$myNum" `
    -dnsNameForPublicIP "mydns$myNum" `
    -adminUsername "admin" `
    -adminPassword ("<PASSWORD>" | ConvertTo-SecureString -AsPlainText -Force) `
    -vmName "myVM$myNum" `
    -windowsOSVersion "2012-R2-Datacenter"
```

## Usage
#### Connect
[How to connect to the solution]
#### Management
[How to manage the solution]

## Notes
[Solution notes]


