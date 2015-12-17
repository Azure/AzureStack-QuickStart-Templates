# Create a 3-VM SharePoint 2013 farm with PowerShell DSC Extension

This template will create a SharePoint 2013 farm using the PowerShell DSC Extension it creates the following resources:

+	A Virtual Network
+	Three Storage Accounts
+	Two external load balancers
+	One VM configured as Domain Controller for a new forest with a single domain
+	One VM configured as SQL Server 2014 stand alone
+	One VM configured as a one machine SharePoint 2013 farm

One external load balancer creates an RDP NAT rule to allow connectivity to the domain controller VM
The second external load balancer creates an RDP NAT rule to allow connectivity to the SharePoint VM
To access the SQL VM use the domain controller or the SharePoint VMs as jumpboxes

## Notes

+ 	The images used to create this deployment are
	+ 	AD - Latest Windows Server 2012 R2 Image
	+ 	SQL Server - Latest SQL Server 2014 on Windows Server 2012 R2 Image
	+	SharePoint Server - Latest SharePoint 2013 on Windows Server 2012 R2 Image

+	The installer bits for SQL 2014 and SharePoint 2013 were pre-loaded into the image
+ 	The image configuration is defined in variables - details below - but the scripts that configure this deployment have only been tested with these versions and may not work on other images.

## Deploying from Portal

+	Login into Azurestack portal
+	Click "New" -> "Custom" -> "Template deployment"
+	Copy conent in azuredeploy.json, Click "Edit Tempalte" and paste content, then Click "Save"
+	Fill the parameters
+	Click "Create new" to create new Resource Group
+	Click "Create"

## Deploying from PowerShell

Download azuredeploy.json and azuredeploy.azurestack.parameters.json to local machine 

Modify parameter value in azuredeploy.azurestack.parameters.json as needed 

Allow cookies in IE: Open IE at c:\Program Files\Internet Explorer\iexplore.exe -> Internet Options -> Privacy -> Advanced -> Click OK -> Click OK again

Launch a PowerShell console

Change working folder to the folder containing this template

```PowerShell

# Add specific Azure Stack Environment 

$AadTenantId = <Tenant Id> #GUID Specific to the AAD Tenant 

Add-AzureRmEnvironment -Name 'Azure Stack' `
    -ActiveDirectoryEndpoint ("https://login.windows.net/$AadTenantId/") `
    -ActiveDirectoryServiceEndpointResourceId "https://azurestack.local-api/" `
    -ResourceManagerEndpoint ("https://api.azurestack.local/") `
    -GalleryEndpoint ("https://gallery.azurestack.local/") `
    -GraphEndpoint "https://graph.windows.net/"

# Get Azure Stack Environment Information 
$env = Get-AzureRmEnvironment 'Azure Stack' 

# Authenticate to AAD with Azure Stack Environment 
Add-AzureRmAccount -Environment $env -Verbose 

# Get Azure Stack Environment Subscription 
$SubName = <Subscription Name> # The sbuscription name is the offer name by default 
Get-AzureRmSubscription -SubscriptionName $SubName | Select-AzureRmSubscription

#Resource group name. Please make sure the resource group does not exist 
$resourceGroupName = "sqlResourceGroup"
$deploymentName = "SqlDeployment"
$location = "Local" 
New-AzurermResourceGroup -Name $resourceGroupName -Location $location 

#Start new Deployment
New-AzurermResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName `
    -TemplateParameterFile .\azuredeploy.azurestack.parameters.json -TemplateFile .\azuredeploy.json