# Deploy a VM Scale Set of Windows VMs with a custom script extension

This template allows you to deploy a VM Scale Set of Windows VMs with a custom script run on each VM. It uses the latest patched version of several Windows versions. To connect from the load balancer to a VM in the scale set, you would go to the AzureStack Portal, find the load balancer of your scale set, examine the NAT rules, then connect using the NAT rule you want. For example, if there is a NAT rule on port 50000, you could RDP on port 50000 of the public IP to connect to that VM. Similarly if something is listening on port 80 we can connect to it using port 80:

# Parameter Restriction

vmssName must be 3-10 characters in length. It should also be globally unique across all of AzureStack. If it isn't globally unique, it is possible that this template will still deploy properly, but we don't recommend relying on this pseudo-probabilistic behavior.
instanceCount must be 20 or less. VM Scale Set supports upto 100 VMs and one should add more storage accounts to support this number.

# Deploy using Az CLI
```Powershell
# update parameters values in azuredeploy.parametrs.json file and run below commands
# create resource group if it doesn't exist
az group create --name testrg --location "local"
# ARM template deployment
az deployment group create --resource-group testrg --template-file .\azuredeploy.json
# Bicep deployment
az deployment group create --resource-group testrg --template-file .\azuredeploy.bicep 
```