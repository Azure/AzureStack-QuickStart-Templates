## AzureStack MySql Adapter RP database ##

<b>DESCRIPTION</b>

This template creates a new MySql database of the specified size and SKU.

<b>PREREQUISITES</b>

This template requires the MySql Adapter RP to be deployed on the AzureStack environment. For more information see: https://aka.ms/azurestackmysqldeploy
Ensure the MySql Adapter RP namespace is registered on your subscription. For more information see the last step on this document: https://aka.ms/azurestackmysqldeploy

<b>DEPLOY</b>

Login to AzureStack portal

Click 'New' -> 'Custom' -> 'Template Deployment'

Copy content in azuredeploy.json, click 'Edit Template', paste all the content and click 'Save'

Fill in the parameters

Click 'Create New' to create a new 'Resource Group'

Click 'Create'

<b>PARAMETERS</b>
```Poweshell
Database Name: <Name of the MySql database to be created>

Database Username: <Name of the MySql login to be created for connecting to the new database>

Database Login Password: <Password of the MySql login to be created for connecting to the new database>

Max Size MB: <Maximum Size in MB of the MySql database>

Collation: <Collation of the new MySql database>

SKU Name: <Name of the requested database SKU>

SKU Tier: <Tier of the requested database SKU>

SKU Family: <Family of the requested database SKU>