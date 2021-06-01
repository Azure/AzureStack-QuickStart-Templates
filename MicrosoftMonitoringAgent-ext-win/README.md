# A template that deploys the Microsoft Monitoring Agent extension to an existing Windows VM and adds it to an existing Azure LogAnalytics workspace.

## Prerequisites
This template requires:
- an existing Azure Stack Windows VM
- the latest version of the "Azure Monitor, Update and Configuration Management” extension downloaded in the Azure Stack Marketplace
- an LogAnalytics workspace created in Azure (more info see [this link](https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-quick-create-workspace))


To enable the [Update Management](https://docs.microsoft.com/en-us/azure/automation/automation-update-management), [Change Tracking](https://docs.microsoft.com/en-us/azure/automation/automation-change-tracking), and [Inventory](https://docs.microsoft.com/en-us/azure/automation/automation-vm-inventory) solutions in Azure, you will also need an Automation Account and to enable those solutions.
For more information on the enabling the solution please see https://aka.ms/azstackupdatemgmt


## Parameters
- vmName: Name of an existing Windows VM to update. 
- workspaceId: Target Azure LogAnalytics workspace ID. 
- password: Target Azure LogAnalytics workspace key.

## Deployment options
1. Add the extension from the Azure Stack VM extension blade - more information [here](https://aka.ms/azstackupdatemgmt)
1. Deploy to Azure Stack portal using custom deployment - use the azuredeploy.json content directly to deploy via the Template Deployment 
2. Deploy through Visual Studio using azuredeploy.json and azuredeploy.parameters.json
2. Deploy the solution from PowerShell with the following PowerShell script 

``` PowerShell
## Specify your AzureAD Tenant in a variable. 
## make sure you have configured the right Azure Stack PowerShell environment
# the ASDK environment will use these settings 

    $ArmEndpoint = "https://management.local.azurestack.external"
    Add-AzureRMEnvironment -Name "AzureStackAdmin" -ArmEndpoint $ArmEndpoint
    Add-AzureRmAccount -EnvironmentName "AzureStackAdmin"

## Select an existing subscription where the deployment will take place
    Get-AzureRmSubscription -SubscriptionName "SUBSCRIPTION_NAME"  | Select-AzureRmSubscription

# Set Deployment Variables
# Make sure the parameters file includes the right LogAnalytics WorkspaceID, Key, and VM name
$RGName = "the_RG_of_the_VM"
$templateFile= "azuredeploy.json"
$templateParameterFile= "azuredeploy.parameters.json"

# Deploy Template 
New-AzureRmResourceGroupDeployment `
    -ResourceGroupName $RGName `
    -TemplateFile $templateFile `
	-TemplateParameterFile $templateParameterFile
```

