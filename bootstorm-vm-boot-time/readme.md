## VM BOOTSTORM WORKLOAD FOR AZURESTACK (LOCAL) ##

<b>DESCRIPTION</b>

This template deploys requested number of VMs and a controller VM with public IP address in same virtual network. Controller VM turn-off all VMs then boot them simultaneously to measure an average and end-to-end VM boot time.

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



