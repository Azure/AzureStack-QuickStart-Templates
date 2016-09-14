## VM Iostorm Workload for Azure and AzureStack ##


<b>DESCRIPTION</b>

This template deploys requested number of VMs and a controller VM with public IP address in same virtual network. Controller VM synchronizes IO workload on all VMs, collects and analyse results and upload it to the storage account.

Please make sure to user unique resource group name for each deployment to avoid deployment failures due to name collisions of resources.

NOTE: There is a 90 minutes time-out for DSC execution, which can cause template deployment to fail if large number of VMs are deployed or if longer execution time is provided to run iostorm test. To circumvent that, all these operations are done using Scheduled Task which gets created by a DSC Script Resource by a Controller VM.


<b>PARAMETERS</b>
```PowerShell
vmCount: 10 #[Number of VMs to deploy and iostorm]
```

<b>RESULTS</b>

VM iostorm results are published inside Azure Storage Account ('uniqueStorageAccountName' variable provided by you) as a table with name 'VMIoResults'


<b>DEPLOY</b>

Login to AzureStack portal

Click 'New' -> 'Custom' -> 'Template Deployment'

Copy content in azuredeploy.json, click 'Edit Template', paste all the content and click 'Save'

Fill in the parameters

Click 'Create New' to create a new 'Resource Group'

Click 'Create'

Wait for results to appear in a 'Azure Storage Account' of a given 'Resource Group' resource

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAzureStack-QuickStart-Templates%2Fmaster%2Fiostorm-vm-iops-latency%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAzureStack-QuickStart-Templates%2Fmaster%2Fiostorm-vm-iops-latency%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

