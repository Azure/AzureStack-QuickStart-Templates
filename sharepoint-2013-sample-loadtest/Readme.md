# Download and run a sample load generation load test against an existing SharePoint farm

This template will prepare the target SharePoint farm for load test execution and download and run a load test on an existing test controller by creating the following resources:

+	One custom script VM extension on an existing SharePoint VM resource to prepare the farm for load testing
+	One custom script VM extension on an existing Visual Studio test controller VM resource to download and execute a load test run


## Notes

+ 	This template assumes that a SharePoint 2013 farm and a VS 2013 TC/TA farm are deployed.
	+ To deploy a SharePoint farm you can use the templates at:
		+ https://github.com/Azure/AzureStack-QuickStart-Templates/tree/master/sharepoint-2013-non-ha
		or 
		+ https://github.com/Azure/AzureStack-QuickStart-Templates/tree/master/sharepoint-2013-single-vm
	+ To deploy the Visual Studio TC/TA farm you can use the template at:
		+ https://github.com/Azure/AzureStack-QuickStart-Templates/tree/master/vs2013-tcta
+ 	This template makes use of nested templates for deploying the VM extensions, the main template (azuredeploy.json) assumes that the SharePoint 2013 and VS 2013 TC/TA farms are deployed
	on the same resource group. If they however are on different resource groups:
	+ Deploy SharePointFarmPrepareForLoadTest.json on the SharePoint 2013 resource group
	+ Deploy TestControllerRunLoadTest.json on the VS 2013 TC/TA resource group
	The above templates can be deployed from the portal or from PowerShell; follow the instructions in the sections bellow but instead of using azuredeploy.json use the above .json files instead.	

## Deploying from Portal

+	Login into Azurestack portal
+	Click "New" -> "Custom" -> "Template deployment"
+	Copy conent in azuredeploy.json, Click "Edit Tempalte" and paste content, then Click "Save"
+	Fill the parameters
+	Click "Create new" to create new Resource Group
+	Click "Create"

## Deploying from PowerShell

Download azuredeploy.json and azuredeploy.parameters.json to local machine 

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
    -TemplateParameterFile .\azuredeploy.parameters.json -TemplateFile .\azuredeploy.json