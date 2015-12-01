# Create a SQL Server 2014 Stand alone with PowerShell DSC Extension

This template will create a SQL Server 2014 Always On Availability Group using the PowerShell DSC Extension it creates the following resources:

+	A Virtual Network
+	Two Storage Accounts
+	One external load balancer
+	One VM configured as Domain Controller for a new forest with a single domain
+	One VM configured as SQL Server 2014 stand alone

The external load balancer creates an RDP NAT rule to allow connectivity to the first VM created, in order to access other VMs in the deployment this VM should be used as a jumpbox.

## Notes

+ 	The images used to create this deployment are
	+ 	AD - Latest Windows Server 2012 R2 Image
	+ 	SQL Server - Latest SQL Server 2014 on Windows Server 2012 R2 Image

+ 	The image configuration is defined in variables - details below - but the scripts that configure this deployment have only been tested with these versions and may not work on other images.

## Deploying from PowerShell

For details on how to install and configure Azure Powershell see [here].(https://azure.microsoft.com/en-us/documentation/articles/powershell-install-configure/)

Launch a PowerShell console

Change working folder to the folder containing this template

```PowerShell

New-AzurermResourceGroupDeployment -Name "<new resourcegroup name>" -Location "<new resourcegroup location>"  -TemplateParameterFile .\azuredeploy.azurestack.parameters.json -TemplateFile .\azuredeploy.json
