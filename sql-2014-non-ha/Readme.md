# Create a SQL Server 2014 Always On Availability Group with PowerShell DSC Extension

This template will create a SQL Server 2014 Stand alone server using the PowerShell DSC Extension it creates the following resources:

+	A Virtual Network
+	Two Storage Accounts
+	One external and one internal load balancer
+	One VM configured as Domain Controllers for a new forest with a single domain
+	One VM configured as Sql Server 2014 stand alone.

The external load balancer creates an RDP NAT rule to allow connectivity to the first VM created, in order to access other VMs in the deployment this VM should be used as a jumpbox.


## Notes

+ 	The images used to create this deployment are
	+ 	AD - Latest Windows Server 2012 R2 Image
	+ 	SQL Server - Latest Windows Server 2012 R2 Image

+ 	The image configuration is defined in variables - details below - but the scripts that configure this deployment have only been tested with these versions and may not work on other images.

## Deploying from PowerShell

For details on how to install and configure Azure Powershell see [here].(https://azure.microsoft.com/en-us/documentation/articles/powershell-install-configure/)

Launch a PowerShell console

Ensure that you are in Resource Manager Mode

```PowerShell

Switch-AzureMode AzureResourceManager

```
Change working folder to the folder containing this template

```PowerShell

New-AzureResourceGroup -Name "<new resourcegroup name>" -Location "<new resourcegroup location>"  -TemplateParameterFile .\azuredeploy.azurestack.parameters.json -TemplateFile .\azuredeploy.json