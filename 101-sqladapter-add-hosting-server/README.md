## AzureStack SQL Adapter RP hosting server ##

<b>DESCRIPTION</b>

This template adds an existing SQL server as a SQL Adapter hosting server.

<b>PREREQUISITES</b>

This template requires the SQL Adapter RP to be deployed on the AzureStack environment. For more information see: https://aka.ms/azurestacksqldeploy
This template requires an existing SQL server to add it as SQL Adapter hosting server;
SQL servers can be created using the following template: https://github.com/Azure/AzureStack-QuickStart-Templates/tree/master/sql-2014-standalone

<b>DEPLOY</b>

Login to AzureStack portal

Click 'New' -> 'Custom' -> 'Template Deployment'

Copy content in azuredeploy.json, click 'Edit Template', paste all the content and click 'Save'

Fill in the parameters

Click 'Create New' to create a new 'Resource Group'

Click 'Create'


<b>PARAMETERS</b>
```Poweshell
Hosting Server Name: <SQL Server FQDN or IPv4 of an existing SQL server to be added as a SQL Adapter hosting server>

Port: <Optional parameter for SQL Server Port, default is 1433>

InstanceName: <Optional parameter for SQL Server Instance>

Total Space MB: <The total space in MB to be allocated for creation of databases on the hosting server>

Hosting Server SQL Login Name: <Name of a SQL login to be used for connecting to the SQL database engine on the hosting server using SQL authentication>

Hosting Server SQL Login Password: <Password for the given SQL login>

SKU Name: <Name of the SQL Adapter SKU to associate the hosting server to>
