## VM IOSTORM WORKLOAD FOR AZURESTACK (LOCAL) ##


<b>DESCRIPTION</b>

This template deploys requested number of VMs and a controller VM with public IP address in same virtual network. Controller VM synchronizes IO workload on all VMs, collects and analyse results and upload it to the storage account.

NOTE: There is a 90 minutes Azure time-out which you can hit if large number of VMs are deployed. To circumvent that, all these operations are done using Scheduled Task which gets created by a DSC Script Resource by a Controller VM.


<b>PARAMETERS</b>

```PowerShell
azureAccountUsername: "user@yourdomain.com" #[Tenant user name used for azure portal login]

azureAccountPassword: "abcd!!00" #[Tenant user password used for azure portal login]

tenantId: "1ab2c3d4-567e-8901-234f-gh0000ijk1l2" #[(Get-AzureRmSubscription).TenantId]

vmCount: 2 #[Number of VMs to deploy and iostorm]
```


<b>RESULTS</b>

VM IO-storm results file is uploaded to Unique Azure Storage Account ('uniqueStorageAccountName' parameter provided by you) as a blob with name 'VMIOResult.log.ps1.zip'


<b>DEPLOY</b>

Login to AzureStack portal

Click 'New' -> 'Custom' -> 'Template Deployment'

Copy content in azuredeploy.azurestack.json, click 'Edit Template', paste all the content and click 'Save'

Fill in the parameters

Click 'Create New' to create a new 'Resource Group'

Click 'Create'

Wait for results to appear in 'Storage Account' of a given 'Resource Group' parameter name resource
