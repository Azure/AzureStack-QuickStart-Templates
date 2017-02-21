# Azure (Stack) Storage Demo with Node.js
This is a web app sample with Node.js bundled with ARM template and DSC Extension.
The web app runs simple scenario tests against Azure Consistent Storage APIs through Azure Node.js SDK. 
The bundle also demonstrates how a tenant could deploy an Azure (Stack) Node.js web application with DSC extension on an Azure (Stack) VM created with an ARM template.

[![Visualize the ARM Template](http://armviz.io/visualizebutton.png "Visualize the ARM Template")](http://armviz.io/#/?load=https://raw.githubusercontent.com/yingqunpku/azurestoragedemo/master/ARMTemplate/Templates/azuredeploy.json)

## Deployment
Normally it will take 15-20 minutes on Azure.com to accomplish the deployment. On Azure Stack POC (TP2 one-node deployment), it takes 20-30 minutes.

You could deploy the app multiple times but only with different resource groups.


### Prerequisites
To deploy this application, you must have one of the following: 
+ A subscription on Azure.com, or 
+ An Azure Stack TP2 deployment, a tenant subscription in that deployment, and a valid connection to your Azure Stack. [(Connect to Azure Stack)](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-connect-azure-stack)

### Tools
You could use one of these three tools to deploy the app:
+ Azure PowerShell [(Install PowerShell and connect to Azure Stack)](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-connect-powershell)
+ Azure CLI [(Install and configure Azure Stack CLI)](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-connect-cli)
+ These magical buttons:
[![Deploy to Azure.com](http://azuredeploy.net/deploybutton.png "Deploy to Azure.com")](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fyingqunpku%2Fazurestoragedemo%2Fmaster%2FARMTemplate%2FTemplates%2Fazuredeploy.json)  [![Deploy to Azure Stack](images/deploytoazurestack.png "Deploy to Azure Stack")](https://portal.azurestack.local/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fyingqunpku%2Fazurestoragedemo%2Fmaster%2FARMTemplate%2FTemplates%2Fazuredeploy.json)


**PowerShell deployment code:**

Step 1. Create a new resource group on the portal or with the following scripts *[OPTIONAL]*
> Select a subscription. If you have no idea about your subscription id, run Get-AzureRmSubscription will list all your subscriptions
> ```PowerShell
> Select-AzureRmSubscription -SubscriptionId <YOUR SUBSCRIPTION ID>
> ```
> Create a resource group with whatever name you like but must be unique. If you have no idea what location to specify, run Get-AzureRmLocation will list all available locations
> ```PowerShell
> New-AzureRmResourceGroup -Name acstest -Location local 
> ```

Step 2. Kickoff the deployment
> ```PowerShell
> New-AzureRmResourceGroupDeployment -Name testdep -ResourceGroupName acstest -TemplateUri "https://raw.githubusercontent.com/yingqunpku/azurestoragedemo/master/ARMTemplate/Templates/azuredeploy.json"  
> ```


### Parameters
There are 5 parameters (2 with default values) for the ARM Template deployed:
+ **"storageEndpoint"**: the target environment. Allowed values include "core.windows.net" and "AzureStack.local".
+ **"adminUsername"**: the Admin username for the Virtual Machine that the template’s going to create.
+ **"adminPassword"**: the password for the admin user. It must contain 3 of the following: 1 lowercase character, 1 uppercase character, 1 number, and 1 special character. Its minimum length is 12 characters.
+ **"configurationFile" & "modulesUrl"**: reserved for Azure China deployment. Keep them as the default values.


## Run the Demo App
On both Azure and Azure Stack, you have to navigate to the portals to retrieve the URL of the demo application.
+ Navigate to the Resource group blade that you've deployed the app with;
+ Click on the resource "myPublicIP";
+ You will get to know the IP address \<IPADDRESS> and DNS name \<DNS> of the app (DNS not applicable for Azure Stack for now).

Navigate to **http://\<IPADDRESS>:3000** or **http://\<DNS>:3000**. 
Then, you will see the page with a form prefilled with some storage account information. 
Go play with it or, alternatively, you could create a storage account by yourself and play with it on the app. Moreover, you could even create a storage account on a different environment and run the app against it, i.e., you could deploy your app in Azure Stack but run the tests against a storage account from Azure Global or Azure China.