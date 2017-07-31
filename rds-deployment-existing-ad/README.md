# Create Remote Desktop Sesson Collection deployment using existing AD.
This template will create a Remote Desktop Sesson Collection farm using the PowerShell DSC Extension. Please note this expects that AD is already setup (The Vnet and Subnet names are currently in variables so, you need to update it to use yours). it creates the following resources:

+	One Storage Account
+	One external load balancer
+	One VM configured as RDS Connection Broker and Licensing Server role
+	One VM configured as RDS Gateway and Web access Server role
+	One (or more) VMs configured as RDSH host role. NOTE: Because HA is not supported on Azure Stack Development Kit, please use only one VM or it will fail.
+ 	The imageSKU is choice in parameter and rest of image configuration is defined in variables - but the scripts that configure this deployment have only been tested with windows server 2012 R2 data center image and may not work on other images.

## Deploying from Portal

+	Login into Azurestack portal
+	Click "New" -> "Custom" -> "Template deployment"
+	Deploy ad-non-ha template. if you already have deployed ad-non-ha, then you can use that AD deployment by its resource group for this deployment.
+	Copy conent in azuredeploy.json, Click "Edit Tempalte" and paste content, then Click "Save"
+	Fill the parameters. Again, this uses existing AD. Please see note above.
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
$resourceGroupName = "rdsResourceGroup"
$deploymentName = "RDSDeployment"
$location = "Local" 
New-AzurermResourceGroup -Name $resourceGroupName -Location $location 

#Start new Deployment
New-AzurermResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName `
��� -TemplateParameterFile .\azuredeploy.parameters.json -TemplateFile .\azuredeploy.json
