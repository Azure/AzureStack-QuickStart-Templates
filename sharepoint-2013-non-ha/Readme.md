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

## Parameters
+	domainName: FQDN of the new domain to be created.
+	sqlServerServiceAccountUserName: Username of the SQL server service account to create.
+	adminUsername: Username of the local Administrator account of the new VMs and domain.
+	adminPassword: Password of the local Administrator account of the new VMs and domain.
+	sharepoint2013SP1DownloadLink: Direct download link for the SharePoint 2013 with SP1 ISO.
+	sharepoint2013ProductKey: Product key for SharePoint 2013 with SP1, required for SharePoint setup.

## Notes
+	This template requires a SharePoint 2013 with SP1 iso for installing the SharePoint server. If the provided iso does not include SP1 setup will fail.
	A direct link for SharePoint 2013 with SP1 iso can be obtained from MSDN subscriber downloads. Note however that MSDN subscribe downloads links expire
	after a period of time. If you have an iso available, place it on a location where it is reachable for the VMs to download (Azure blob storage for example)
+	This template requires a product key for SharePoint 2013. A trial key for SharePoint 2013 can be found on MSDN subscriber downloads or from the TechNet
	evaluation center.
	
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAzureStack-QuickStart-Templates%2Fmaster%2Fsharepoint-2013-non-ha%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAzureStack-QuickStart-Templates%2Fmaster%2Fsharepoint-2013-non-ha%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

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