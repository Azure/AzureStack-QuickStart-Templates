# Minikube on AzureStack
This template deploys a Ubuntu 16.04 virtual machine on AzureStack running Minikube to manage kubenetes cluster.

## Prerequisites
Follow the below links to create/download an Ubuntu 16.04 LTS Image and upload the same to Azure Stack's Platform Image Repository(PIR)
1. https://azure.microsoft.com/en-us/documentation/articles/azure-stack-linux/
2. https://azure.microsoft.com/en-us/documentation/articles/azure-stack-add-image-pir/
	Note: please use the default values for linuxPublisher,linuxOffer,linuxSku,linuxVersion found in azuredeploy.json while creating the manifest.json in PIR

## Deploying from Portal

+	Login into Azurestack portal
+	Click "New" -> "Custom" -> "Template deployment -> "Edit Template" -> "Load File" -> Select azure.deploy.json from the local drive -> "Save"
+ Click "Edit Parameters" and 	Fill the parameters. Please note down the admin name and password for later use
+	Select "Create new" to create new Resource Group and give a new resource group name
+	Click "Create"
+ Wait until the template deployment is completed

## Deploying from PowerShell

Download azuredeploy.json and azuredeploy.azurestack.parameters.json to local machine 

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
$resourceGroupName = "minikubeResourceGroup"
$deploymentName = "minikubeDeployment"
$location = "Local" 
New-AzurermResourceGroup -Name $resourceGroupName -Location $location 

#Start new Deployment
New-AzurermResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName `
��� -TemplateParameterFile .\azuredeploy.parameters.json -TemplateFile .\azuredeploy.json

```

## What is Minikube
Minikube is a tool that makes it easy to run Kubernetes locally. Minikube runs a single-node Kubernetes cluster inside a VM on your laptop for users looking to try out Kubernetes or develop with it day-to-day.

Here is a brief overview of the minikube deployment on azurestack
![Image of Minikube architecture](https://github.com/vpatelsj/AzureStack-QuickStart-Templates/blob/master/101-vm-linux-minikube/images/minikubearch.png)
