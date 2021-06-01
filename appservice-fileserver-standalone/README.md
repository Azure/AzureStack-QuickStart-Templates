# Create a Standalone file server for App Service

This template will creates App Service standalone file server for test scenarios.

The template will return public IP of newly created standalone file server which can be used for App Service deployment on ASDK. E.g. \\\\publicIp\Websites OR \\\\fqdn\Websites

It also creates the following resources:
+   A Virtual Network
+   One Storage Account and subnet
+   One Public IP
+   One Virtual machine configured for App Service standalone file server

## Notes
Standalone file server is not HA and should only be used in dev and test scenarios.

This template uses an Azure Stack Marketplace image, which must be downloaded from Azure Marketplace and made available on your Azure Stack instance:
- The latest version of Windows Server 2016 Datacenter

<!--
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAzureStack-QuickStart-Templates%2Fmaster%2Fappservice-fileserver-standalone%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
-->
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAzureStack-QuickStart-Templates%2Fmaster%2Fappservice-fileserver-standalone%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>


## Deploying from Azure Stack portal

+   Copy azuredeploy.json content to clipboard.
+   Sign in to portal.
+   Click "+ Create a resource" -> "Custom" -> "Template deployment".
+   Click "Edit template"
+   Delete existing content, paste in content from clipboard, then click "Save".
+   Click "Edit parameters" to complete any missing/incorrect parameters, then click "OK".
+   Specify the appropriate subscription and resource group settings.
+   Click "Create".
