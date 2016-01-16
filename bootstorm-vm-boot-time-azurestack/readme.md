## VM BOOTSTORM WORKLOAD ##

<b>DESCRIPTION</b>

This template deploys requested number of VMs and a controller VM with public IP address in same virtual network. Controller VM turn-off all VMs then boot them simultaneously to measure an average and end-to-end VM boot time.

NOTE: There is a 90 minutes Azure time-out which you can hit if large number of VMs are deployed. To circumvent that, all these operations are done using Scheduled Task (script: VMBootAllScript.ps1) which gets created by a DSC Script Resource (script: VMBootAll.ps1).


<b>RESULTS</b>

VM bootstorm results file is uploaded to Unique Azure Storage Account ('uniqueStorageAccountName' parameter provided by you) as a blob with name 'VMBootAllResult.log.ps1.zip'


<b>DEPLOY</b>

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazurestack-quickstart-templates%2Fmaster%2Fbootstorm-vm-boot-time%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>


<b>PARAMETERS</b>

Azure AD Application Id: <Application ID returned by New-AzureADServicePrincipal cmdlet while setting up Azure SPN Configuration>

Azure AD Application Password: <Password you entered for New-AzureADServicePrincipal cmdlet while setting up Azure SPN Configuration>

Tenant Id: (Get-AzureSubscription).TenantId

Unique Dns Name for PublicIP: <Choose any string value unique across Azure>

Unique Storage Account Name: <Choose any string value unique across Azure>

Location: <Location where Azure resources will be deployed>

VM Admin User Name: <Choose secure username for VMs>

VM Admin Password: <Choose secure password for VMs>

VM Count: <Choose number of VMs to deploy>

VM OS Sku: <Choose version of Windows to deploy>