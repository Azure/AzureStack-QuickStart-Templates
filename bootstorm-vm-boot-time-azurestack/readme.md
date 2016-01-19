## VM BOOTSTORM WORKLOAD ##

<b>DESCRIPTION</b>

This template deploys requested number of VMs and a controller VM with public IP address in same virtual network. Controller VM turn-off all VMs then boot them simultaneously to measure an average and end-to-end VM boot time.

NOTE: There is a 90 minutes Azure time-out which you can hit if large number of VMs are deployed. To circumvent that, all these operations are done using Scheduled Task (script: VMBootAllScript.ps1) which gets created by a DSC Script Resource (script: VMBootAll.ps1) by a Controller VM.


<b>RESULTS</b>

VM bootstorm results file is uploaded to Unique Azure Storage Account ('uniqueStorageAccountName' parameter provided by you) as a blob with name 'VMBootAllResult.log.ps1.zip. Detailed logs are also uploaded alongside with name VMBootAll.log.ps1.zip.'


<b>DEPLOY</b>
Login to AzureStack portal
Click 'New' -> 'Custom' -> 'Template Deployment'
Copy content in azuredeploy.json, click 'Edit Template', paste all the content and click 'Save'
Fill in the parameters
Click 'Create New' to create a new 'Resource Group'
Click 'Create'
Wait for results to appear in 'Storage Account' of a given 'Resource Group' parameter name resource

<b>PARAMETERS</b>

azureUser: Tenant user name
azurePassword: Tenant user password
azureApplicationId: Application id of AzureStack e.g. "https://azurestack.local-api/"
tenantId: Tenant id of AzureStack e.g. (Get-AzureSubscription).TenantId
uniqueDnsNameForPublicIP: <Choose any string value unique across Azure>
uniqueStorageAccountName: <Choose any string value unique across Azure>
location: "local" for AzureStack
vmAdminUsername: <Your VM admin username>
vmAdminPassword: <Your VM admin password>
vmCount: Number of VMs to deploy and bootstorm
vmOsSku: e.g. "2012-R2-Datacenter"