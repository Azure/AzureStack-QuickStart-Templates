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

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAzureStack-QuickStart-Templates%2Fmaster%2Fappservice-fileserver-standalone%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAzureStack-QuickStart-Templates%2Fmaster%2Fappservice-fileserver-standalone%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>


## Deploying from Portal

+   Login into Azurestack portal
+   Click "New" -> "Custom" -> "Template deployment"
+   Copy conent in azuredeploy.json, Click "Edit Template" and paste content, then Click "Save"
+   Fill the parameters
+   Click "Create new" to create new Resource Group
+   Click "Create"