# IaaS Linux VM using managed disk from custom image

This template deploys a Linux VM from a Custom Image using Managed Disk  

# Prerequisites
Prepare or Download a Customized Linux Image Template

# Deploy using Az CLI
```Powershell
# update parameters values in azuredeploy.parametrs.json file and run below commands
# create resource group if it doesn't exist
az group create --name testrg --location "local"
# ARM template deployment
az deployment group create --resource-group testrg --template-file .\azuredeploy.json --parameters .\azuredeploy.parameters.json
# Bicep deployment
az deployment group create --resource-group testrg --template-file .\azuredeploy.bicep --parameters .\azuredeploy.parameters.json  
```