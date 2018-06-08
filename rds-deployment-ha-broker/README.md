# Provide High Availability to RD Connection Broker servers in RDS deployment

This template deploys the following resources:

* a second RD Connection Broker VM including a NIC and StorageAccount

The template will

* Create a new VM and join the new VM to the domain
* Prepare the existing RDS Deployment for RDCB HA
* Add the RD Connection Broker role to the new VM and join it to the deployment

### Prerequisites

Current Template is an extension to the Basic RDS Deployment Template, and it is mandatory to deploy any one of the template as prerequisite:

* Basic RDS deployment template  
  https://github.com/Azure/azure-quickstart-templates/tree/master/rds-deployment 

* RDS deployment on pre-existing VNET and AD  
  https://github.com/Azure/azure-quickstart-templates/tree/master/rds-deployment-existing-ad

* An Azure SQL Database, or a VM running SQL Server also needs to be in place to house the RDCB Database

This template expects the same names of resources from RDS deployment, if resource names are changed in your deployment then please edit the parameters and resources accordingly, example of such resources are below:
<ul>
<li>storageAccountName: Resource must be exact same to existing RDS deployment.</li>
<li>publicIpRef: Resource must be exact same to existing RDS deployment.</li>
<li>availabilitySets: Resource must be exact same to existing RDS deployment.</li>
<li>Load-balancer: Load balancer name, Backend pool, LB-rules, Nat-Rule and NIC.</li>
<li>VM’s – VM name classification which is using copy index function.</li>
<li>NIC – NIC naming convention.</li>
</ul>


Click the button below to deploy

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FRDS-Templates%2Fmaster%2Frds-deployment-ha-broker%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FRDS-templates%2Fmaster%2Frds-deployment-ha-broker%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>
