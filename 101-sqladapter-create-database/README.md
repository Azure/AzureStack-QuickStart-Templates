## AzureStack SQL Adapter RP database ##

<b>DESCRIPTION</b>

This template creates a new SQL database of the specified size and SKU.

<b>PREREQUISITES</b>

This template requires the SQL Adapter RP to be deployed on the AzureStack environment. For more information see: https://aka.ms/azurestacksqldeploy
Ensure the SQL Adapter RP namespace is registered on your subscription. For more information see the last step on this document: https://aka.ms/azurestacksqldeploy

<b>DEPLOY</b>

Login to AzureStack portal

Click 'New' -> 'Custom' -> 'Template Deployment'

Copy content in azuredeploy.json, click 'Edit Template', paste all the content and click 'Save'

Fill in the parameters

Click 'Create New' to create a new 'Resource Group'

Click 'Create'

Wait for results to appear in 'Storage Account' of a given 'Resource Group' parameter name resource

<b>PARAMETERS</b>
```Poweshell
Database Name: <Name of the SQL database to be created>

Database Login Name: <Name of the SQL login to be created for connecting to the new database>

Database Login Password: <Password of the SQL login to be created for connecting to the new database>

Collation: <Collation of the new SQL database>

Database Size MB: <Size in MB of the SQL database to be created>

SKU Name: <Name of the requested database SKU>

SKU Tier: <Tier of the requested database SKU>

SKU Family: <Family of the requested database SKU>
