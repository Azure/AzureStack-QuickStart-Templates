# Create a Visual Studio 2013 TC/TA farm for load testing with PowerShell DSC Extension

This template will create a Visual Studio 2013 test controller/test agent farm using the PowerShell DSC Extension it creates the following resources:

+	One external load balancer
+	At least two storage accounts (more will be created depending on the selected number of test agents to be deployed)
+	One VM configured as test console that has Visual Studio 2013, SQL Server 2014 (load test database) and test controller

The external load balancer creates an RDP NAT rule to allow connectivity to the console VM.
The components are connected to an existing virtual network to allow connectivity to the target endpoints for load testing.

## Prerequisites
+	An existing Virtual network connected to a domain controller (this is usually the network of the environment to be tested)
+	Visual Studio 2013 Ultimate product key: required for installation of Visual Studio on the test console machine

## Parameters
+	domainName: Name of the existing domain to which the new VMs will join
+	targetResourceGroupName: Name of the resource group that contains the virtual network to which the new VMs will connect to
+	targetVMNetworkName: Name of the existing VM network to connect to
+	targetVMNetworkSubnetName: Name of the exsisting subnet to connect to
+	adminUsername: The name of the Administrator of the new VMs and Domain
+	adminPassword: The password for the Administrator account of the new VMs and Domain
+	serviceAccountUserName: The name of the user account under which the test controller and test agent services will run
+	serviceAccountPassword: The password of the user account under which the test controller and test agent services will run
+	testAgentCount: Number of test agent VMs to create
+	VisualStudioProductKey: Product key (25 characters no spaces) for Visual Studio activation

## Notes
+ 	The image used to create this deployment is
	+ 	Latest Windows Server 2012 R2 Image with .Net 3.5
+	The installer bits for SQL 2014 and Visual Studio 2013 Ultimate with Update 5 are downloaded at deployment time but can be pre-loaded into the image.
	SQL 2014 trial can be downloaded here: https://www.microsoft.com/en-us/evalcenter/evaluate-sql-server-2014. 
	After downloading the ISO, extract the files to a folder called SQL2014 on the image

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
