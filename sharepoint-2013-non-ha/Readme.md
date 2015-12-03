# Create a 3-VM SharePoint 2013 farm with PowerShell DSC Extension

This template will create a SharePoint 2013 farm using the PowerShell DSC Extension it creates the following resources:

+	A Virtual Network
+	Three Storage Accounts
+	Two external load balancers
+	One VM configured as Domain Controller for a new forest with a single domain
+	One VM configured as SQL Server 2014 stand alone
+	One VM configured as a one machine SharePoint 2013 farm

One external load balancer creates an RDP NAT rule to allow connectivity to the domain controller VM
The second external load balancer creates an RDP NAT rule to allow connectivity to the SharePoint VM
To access the SQL VM use the domain controller or the SharePoint VMs as jumpboxes

## Notes

+ 	The images used to create this deployment are
	+ 	AD - Latest Windows Server 2012 R2 Image
	+ 	SQL Server - Latest SQL Server 2014 on Windows Server 2012 R2 Image
	+	SharePoint Server - Latest SharePoint 2013 on Windows Server 2012 R2 Image

+	The installer bits for SQL 2014 and SharePoint 2013 were pre-loaded into the image
+ 	The image configuration is defined in variables - details below - but the scripts that configure this deployment have only been tested with these versions and may not work on other images.

## Deploying from PowerShell

For details on how to install and configure Azure Powershell see [here].(https://azure.microsoft.com/en-us/documentation/articles/powershell-install-configure/)

Launch a PowerShell console

Change working folder to the folder containing this template

```PowerShell

New-AzurermResourceGroupDeployment -Name "<new resourcegroup name>" -Location "<new resourcegroup location>"  -TemplateParameterFile .\azuredeploy.azurestack.parameters.json -TemplateFile .\azuredeploy.json
