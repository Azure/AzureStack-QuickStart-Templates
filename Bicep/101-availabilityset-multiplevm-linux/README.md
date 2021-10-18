# Multiple VM Availability Set

Deploys a set of Linux VM´s (centos ) as part of the same availability set. This template template also deploys an availability set, a virtual Network (with DNS), a load balancer with a front end Public IP address, and a Network Security Group.
VM´s require the following Deployed Centos or Ubuntu Image:
*osImagePublisher: Centos, Canonical
*osImageOffer: Centos-7, UbuntuServer
*osImageSKU: Centos-7.4, 16.04-LTS

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

