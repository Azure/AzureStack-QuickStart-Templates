## AzureStack SQL Adapter RP hosting server ##

<b>DESCRIPTION</b>

This template adds an existing MySQL server as a MySQL Adapter hosting server.

<b>PREREQUISITES</b>

This template requires the MySQL Adapter RP to be deployed on the AzureStack environment. For more information see: https://aka.ms/azurestackmysqldeploy
This template requires an existing MySQL server to add it as MySQL Adapter hosting server.

<b>DEPLOY</b>

Login to AzureStack portal

Click 'New' -> 'Custom' -> 'Template Deployment'

Copy content in azuredeploy.json, click 'Edit Template', paste all the content and click 'Save'

Fill in the parameters

Click 'Create New' to create a new 'Resource Group'

Click 'Create'

<b>PARAMETERS</b>
```Poweshell
HostingServerName: <MySQL Server FQDN or IP address of an existing MySQL server to be added as a MySQL Adapter hosting server>

Port: <Optional parameter for MySQL Server Port, default is 3306>

Username: <Name of a MySQL login to be used for connecting to the MySQL database engine on the hosting server using MySQL authentication>

Password: <Password for the given MySQL login>

Total Space MB: <The total space in MB to be allocated for creation of databases on the hosting server>

SKU Name: <Name of the MySQL Adapter SKU to associate the hosting server to>
