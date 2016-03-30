## VM IOSTORM WORKLOAD FOR AZURE (CLOUD) ##


<b>DESCRIPTION</b>

This template deploys requested number of VMs and a controller VM with public IP address in same virtual network. Controller VM synchronizes IO workload on all VMs, collects and analyze results and upload it to the storage account.

For controller VM to upload results to Azure Storage Account, Azure SPN needs to be configured using instructions given below. (This is required especially for accounts with Multi-Factor authentication enabled by the system admins.)

Please make sure to user unique resource group name for each deployment to avoid deployment failures due to name collisions of resources.

NOTE: There is a 90 minutes Azure time-out which you can hit if large number of VMs are deployed. To circumvent that, all these operations are done using Scheduled Task which gets created by a DSC Script Resource by a Controller VM.


<b>PARAMETERS</b>
```PowerShell
azureAccountUsername: "1ab2c3d4-56e7-8901-f2g3-45hi67890123" #[As per Azure SPN Configuration instructions given below, use $azureAdApp.ApplicationId]

azureAccountPassword: "azureadpwd123" #[As per Azure SPN Configuration instructions given below, use $azureAdPassword]

tenantId:"72f988bf-86f1-41af-91ab-2d7cd011db47" #[(Get-AzureRmSubscription).TenantId]

vmCount: 2 #[Number of VMs to deploy and iostorm]
```

<b>RESULTS</b>

VM iostorm results file is uploaded to Unique Azure Storage Account ('uniqueStorageAccountName' parameter provided by you) as a blob with name 'VMIOResult.log.ps1.zip'


<b>DEPLOY</b>

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAzureStack-QuickStart-Templates%2Fmaster%2Fiostorm-vm-iops-latency%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>


<b>AZURE SPN CONFIGURATION</b>
```PowerShell
New-AzureRmADApplication -Password <any string to use as a password> `
 -DisplayName <Any String Name> `
 -IdentifierUris https://<UseAnyUniqueName e.g. serviceprinciplenm> `
 -HomePage <same as IdentifierUris>
```
<i>Use ApplicationId returned by above cmdlet</i>
```PowerShell
New-AzureRmADServicePrincipal -ApplicationId <ApplicationId>

New-AzureRmRoleAssignment -RoleDefinitionName Owner -ServicePrincipalName "https://<same as IdentifierUris>"
```


<b>SAMPLE AZURE SPN CONFIGURATION COMMANDS</b>
```PowerShell
$azureSubscriptionId = "<Your Azure subscription id (Get-AzureSubscription).SubscriptionId>"

$azureAdIdUri = "https://azureadiduri"

$azureAdPassword = "azureadpwd123"

$azureAdDisplayName = "azureaddisplayname"

Add-AzureRmAccount

Select-AzureRmSubscription -SubscriptionID $azureSubscriptionId

$azureAdApp = New-AzureRmADApplication -Password $azureAdPassword `
-DisplayName $azureAdDisplayName `
-IdentifierUris $azureAdIdUri `
-HomePage $azureAdIdUri

New-AzureRmADServicePrincipal -ApplicationId $azureAdApp.ApplicationId

New-AzureRmRoleAssignment -RoleDefinitionName Owner -ServicePrincipalName $azureAdIdUri
```