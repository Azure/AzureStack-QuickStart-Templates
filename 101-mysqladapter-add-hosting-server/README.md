## AzureStack SQL Adapter RP hosting server ##

<b>DESCRIPTION</b>

This template adds an existing MySql server as a MySql Adapter hosting server.

<b>PREREQUISITES</b>

This template requires the MySql Adapter RP to be deployed on the AzureStack environment. For more information see: https://aka.ms/azurestackmysqldeploy
This template requires an existing MySql server to add it as MySql Adapter hosting server.

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
Name: <MySql Server FQDN or IP address of an existing MySql server to be added as a MySql Adapter hosting server>

Username: <Name of a MySql login to be used for connecting to the MySql database engine on the hosting server using MySql authentication>

Password: <Password for the given MySql login>

Total Space MB: <The total space in MB to be allocated for creation of databases on the hosting server>
