## VM IOSTORM WORKLOAD FOR AZURESTACK (LOCAL) ##

<b>DESCRIPTION</b>

This template deploys requested number of VMs and a controller VM with public IP address in same virtual network. Controller VM synchronizes IO workload on all VMs, collects and analyze results and upload it to the storage account.

NOTE: There is a 90 minutes Azure time-out which you can hit if large number of VMs are deployed. To circumvent that, all these operations are done using Scheduled Task which gets created by a DSC Script Resource by a Controller VM.


<b>RESULTS</b>

VM iostorm results file is uploaded to Unique Azure Storage Account ('uniqueStorageAccountName' parameter provided by you) as a blob with name 'VMIOResult.log.ps1.zip'


<b>DEPLOY</b>


Login to AzureStack portal

Click 'New' -> 'Custom' -> 'Template Deployment'

Copy content in azuredeploy.json, click 'Edit Template', paste all the content and click 'Save'

Fill in the parameters

Click 'Create New' to create a new 'Resource Group'

Click 'Create'

Wait for results to appear in 'Storage Account' of a given 'Resource Group' parameter name resource


<b>PARAMETERS</b>
```PowerShell
azureUser: "tenantadmin1@microsoftazurestack.onmicrosoft.com" #[Tenant user name used for azure portal login]

azurePassword: "abcd!!00" #[Tenant user password used for azure portal login]

azureApplicationId: "https://azurestack.local-api/"

tenantId: "7ea3e2b7-334d-4083-807b-fa2000faa9b8" #[(Get-AzureRmSubscription).TenantId]

uniqueDnsNameForPublicIP: "vmiodns"

uniqueStorageAccountName: "vmiosa"

location: "local"

vmAdminUsername: "vmbootadmin"

vmAdminPassword: "abcd00!!"

vmCount: 2 #[Number of VMs to deploy and iostorm]

vmOsSku: "2012-R2-Datacenter" #[Operating System sku to be deployed in VMs]
```