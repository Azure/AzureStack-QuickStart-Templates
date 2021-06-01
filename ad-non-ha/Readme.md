# Create a AD domain controller server non-HA with PowerShell DSC Extension

This template will create a AD domain controller Server using the PowerShell DSC Extension; it creates the following resources:

+	A Virtual Network
+	One Storage Account
+	One external load balancer
+	One A1 size VM configured as Domain Controller for a new forest with a single domain

The external load balancer creates an RDP NAT rule to allow connectivity to the AD VM created.

## Notes

+   `For VM with managed disk deployment template, refer to "active-directory-new-domain".`
+ 	The images used to create this deployment are
	+ 	AD - Latest Windows Server 2012 R2 Image
+	The VM size, storage type on which the VM is created , subnet and IP address can be updated before deployment. 
+	All the resources will be deployed in the same location as the resource group.
+ 	The image configuration is defined in variables - details below - but the scripts that configure this deployment have only been tested with version mentioned above and may not work on other images.

## Deploying from Portal

+	Login into Azurestack portal
+	Click "New" -> "Custom" -> "Template deployment"
+	Copy conent in azuredeploy.json, Click "Edit Template" and paste content, then Click "Save"
+	Fill the parameters
+	Click "Create new" to create new Resource Group
+	Click "Create"


## Deploying from PowerShell

Download azuredeploy.json and azuredeploy.parameters.json to local machine 

Modify parameter value in azuredeploy.parameters.json as needed 

Allow cookies in IE: Open IE at c:\Program Files\Internet Explorer\iexplore.exe -> Internet Options -> Privacy -> Advanced -> Click OK -> Click OK again

Launch a PowerShell console

Change working folder to the folder containing this template

```PowerShell

# Add specific Azure Stack Environment 

$AadTenantId = <Tenant Id> #GUID Specific to the AAD Tenant 

Add-AzureRmEnvironment -Name 'Azure Stack' `
��� -ActiveDirectoryEndpoint ("https://login.windows.net/$AadTenantId/") `
��� -ActiveDirectoryServiceEndpointResourceId "https://azurestack.local-api/" `
��� -ResourceManagerEndpoint ("https://api.azurestack.local/") `
��� -GalleryEndpoint ("https://gallery.azurestack.local/") `
��� -GraphEndpoint "https://graph.windows.net/"

# Get Azure Stack Environment Information 
$env = Get-AzureRmEnvironment 'Azure Stack' 

# Authenticate to AAD with Azure Stack Environment 
Add-AzureRmAccount -Environment $env -Verbose 

# Get Azure Stack Environment Subscription 
$SubName = <Subscription Name> # The sbuscription name is the offer name by default 
Get-AzureRmSubscription -SubscriptionName $SubName | Select-AzureRmSubscription

#Resource group name. Please make sure the resource group does not exist 
$resourceGroupName = "adResourceGroup"
$deploymentName = "adDeployment"
$location = "Local" 
New-AzurermResourceGroup -Name $resourceGroupName -Location $location 

#Start new Deployment
New-AzurermResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName `
��� -TemplateParameterFile .\azuredeploy.parameters.json -TemplateFile .\azuredeploy.json