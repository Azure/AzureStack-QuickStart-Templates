# SharePoint 2013 non-ha personal sites load test on AzureStack

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fsharepoint-2013-non-ha-loadtest%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/></a>

This template deploys a load test for SharePoint 2013 personal sites. This template will prepare the target SharePoint farm for load test execution and download and run the load test on an existing test controller 

`Tags: sharepoint, loadtest, workload`

| Endpoint        | Version           | Validated  |
| ------------- |:-------------:| -----:|
| Microsoft Azure      | - | no |
| Microsoft Azure Stack      | -     |  no |

## Deployed resources

The following resources are deployed as part of the solution

####[SharePointFarmPrepareForLoadTest]
[Prepares the target SharePoint 2013 server for personal sites load testing]
+ **[Custom script VM extension]**: [Enables the search, managed metadata, and user profile SharePoint services. It also provisions the personal sites for the target number of test users]

####[SQLPrepareForLoadTest]
[Prepares the SQL server of the target SharePoint 2013 farm for load testing]
+ **[Custom script VM extension]**: [Enables remote collecting of performance counters]

####[TestControllerRunLoadTest]
[Downloads, prepares, and executes the load test on a pre-existing Visual Studio test controller]
+ **[Custom script VM extension]**: [Downloads the load test package; sets the target endpoints on the load tests; and executes the requested load test]

## Prerequisites
+ A SharePoint 2013 non-HA farm is required. A farm can be provisioned by using the template located at: https://github.com/Azure/AzureStack-QuickStart-Templates/tree/master/sharepoint-2013-non-ha	
+ A Visual Studio TC/TA deployment is required. The deployment can be provisioned by using the template located at: https://github.com/Azure/AzureStack-QuickStart-Templates/tree/master/vs2013-tcta
+ The SharePoint farm and the TC/TA deployments must be connected to the same VM network and subnet.
+ This template assumes that the computer names for the machines to be tested are the same as their corresponding VM resource names

## Deployment steps
You can either click the "deploy to Azure" button at the beginning of this document or deploy the solution from PowerShell with the following PowerShell script.

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
$myNum = 0
$TestControllerVMName = "sprg-tc-0"
$TestControllerServiceUserName = "tcserv"
$TargetSharePointServerVMName = "sprg-sp-0"
$TargetSQLServerVMName = "sprg-sql-0"
$TargetSharePointServerAdminUserName = "Administrator"
$TargetSharePointServerUserPassword = "GEN-PASSWORD"
$TargetSharePointSiteURL = "http://sprg-sp-0.contoso.com"
$NumberOfLoadTestUsers = 15
$LoadTestToRun = "MySiteHostRW.loadtest"
$VisualStudioVersionNumber = 12

# Create Resource Group for Template Deployment
New-AzureRmResourceGroup -Name $RGName -Location $myLocation

# Deploy Template 
New-AzureRmResourceGroupDeployment `
    -Name "myDeployment$myNum" `
    -ResourceGroupName $RGName `
    -TemplateFile "azuredeploy.json" `
    -deploymentLocation $myLocation `	
    -TestControllerVMName $TestControllerVMName `
    -TestControllerServiceUserName $TestControllerServiceUserName `
    -TargetSharePointServerVMName $TargetSharePointServerVMName `
    -TargetSQLServerVMName $TargetSQLServerVMName `
    -TargetSharePointServerAdminUserName $TargetSharePointServerAdminUserName `
    -TargetSharePointServerUserPassword $TargetSharePointServerUserPassword `
    -TargetSharePointSiteURL $TargetSharePointSiteURL `
    -NumberOfLoadTestUsers $NumberOfLoadTestUsers `
	-LoadTestToRun $LoadTestToRun `
	-VisualStudioVersionNumber $VisualStudioVersionNumber
```

## Usage
#### Connect
Connect to the test controller VM, the results from the load test run will be placed at C:\LoadTestResults

## Notes
+ The load tests used by this template was generated from a SharePoint load generation tool located at: https://visualstudiogallery.msdn.microsoft.com/04d66805-034f-4f6b-9915-403009033263?SRC=VSIDE
+ This template makes use of nested templates for deploying the VM extensions, the main template (azuredeploy.json) assumes that the SharePoint 2013 and VS 2013 TC/TA farms are deployed
on the same resource group. If they however are on different resource groups deploy azuredeploy.SharePointFarmPrepareForLoadTest.json and azuredeploy.SQLPrepareForLoadTest.json on the SharePoint 2013 resource group
and deploy azuredeploy.TestControllerRunLoadTest.json on the VS 2013 TC/TA resource group.
+ There are 3 load tests provided by this solution: CSOMListRW.loadtest (client model add/remove list), MySiteHostRW.loadtest (personal site host page read/write), and MySiteRW.loadtest (personal site read/write)

