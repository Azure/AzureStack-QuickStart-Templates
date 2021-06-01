# A template that creates a simple Windows VM and joins it to an existing domain using VM extension 


## Changes

    Updates in 2019-11:
        - Update VM name convention. 
        - Update VM with managed disk. 
        - Rename original template to azuredeploy-unmanagedDisk.json.


## Prerequisites
1. Template requires a pre-existing domain to join.A domain controller can be deployed using the template located at: 
https://github.com/Azure/AzureStack-QuickStart-Templates/tree/master/ad-non-ha
2. The template asumes that the VM to be created will be connected to a subnet that can access the target domain controller

## Parameters
- vmName: Name of the Virtual Machine to be created. 
- adminUsername: Username for the Virtual Machine local administrator. 
- adminPassword: Password for the Virtual Machine local administrator. 
- dcVNetName: Name of the extisting VNet that contains the domain controller
- dcSubnetName: Name of the existing subnet that contains the domain controller
- domainToJoin: FQDN of the AD domain to join
- ouToJoin: Specifies an AD organizational unit (OU) for the computer to join. Enter the full distinguished name of the OU in quotation marks. 
  Example: 'OU=testOU; DC=domain; DC=Domain; DC=com'. This value can be empty
- domainJoinOptions: Set of bit flags that define the join options. Default value of 3 is a combination of NETSETUP_JOIN_DOMAIN (0x00000001) & NETSETUP_ACCT_CREATE (0x00000002) 
  i.e. will join the domain and create the account on the domain. For more information see https://msdn.microsoft.com/en-us/library/aa392154(v=vs.85).aspx
- domainUserName: Username of the domain account to be used for joining the domain
- domainPassword: Password of the domain account to be used for joining the domain

## Deployment steps
1. Deploy to azure stack portal using custom deployment.
2. Deploy through Visual Studio using azuredeploy.json and azuredeploy.parameters.json
2. Deploy the solution from PowerShell with the following PowerShell script 

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
