# Create a Visual Studio 2013 TC/TA farm for load testing with PowerShell DSC Extension

This template will create a Visual Studio 2013 test controller/test agent farm using the PowerShell DSC Extension it creates the following resources:

+	One external load balancer
+	At least two storage accounts (more will be created depending on the selected number of test agents to be deployed)
+	One VM configured as test console that has Visual Studio 2013, SQL Server 2014 (load test database) and test controller

The external load balancer creates an RDP NAT rule to allow connectivity to the console VM.
The components are connected to an existing virtual network to allow connectivity to the target endpoints for load testing.

## Notes

+ 	The image used to create this deployment is
	+ 	Latest Windows Server 2012 R2 Image with .Net 3.5
+	The installer bits for SQL 2014 and Visual Studio 2013 Ultimate with Update 5 are downloaded at deployment time but can be pre-loaded into the image.
	SQL 2014 trial can be downloaded here: https://www.microsoft.com/en-us/evalcenter/evaluate-sql-server-2014. 
	After downloading the ISO, extract the files to a folder called SQL2014 on the image
+ 	The image configuration is defined in variables - details below - but the scripts that configure this deployment have only been tested with these versions and may not work on other images.
+	Required workaround for Azure Stack TP:
	+	Add a DNS forwarder to address 192.168.100.2 on the DNS server for the network to which the TC/TA farm will be connected to before deploying this template.
		This can be done via PowerShell by running the following commandlet on the DNS machine: Add-DnsServerForwarder -IPAddress "192.168.100.2"

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
$SubName = <Subscription Name> # The subscription name is the offer name by default 
Get-AzureRmSubscription -SubscriptionName $SubName | Select-AzureRmSubscription

#Resource group name. Please make sure the resource group does not exist (optional, this template can be deployed to an existing resource group)
$resourceGroupName = "sqlResourceGroup"
$deploymentName = "SqlDeployment"
$location = "Local" 
New-AzurermResourceGroup -Name $resourceGroupName -Location $location 

#Start new Deployment
New-AzurermResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName `
    -TemplateParameterFile .\azuredeploy.azurestack.parameters.json -TemplateFile .\azuredeploy.json