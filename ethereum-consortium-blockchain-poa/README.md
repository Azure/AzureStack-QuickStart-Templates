# Deploy Ethereum Proof-Of-Authority on Azure Stack
This template deploys all of the resources required for Ethereum POA.   

## Prerequisites
* Download following images from the Marketplace:
    - Ubuntu Server 16.04 LTS (any version)
    - Custom Script for Linux 2.0

* Create a service principal. 
    - On AAD environment save service principal's ID and secret. 
    - On ADFS environment, save service principal's ID and Thumbprint. In addition, create a keyvault with a secret and store service principal's certificate in the keyvault's secret.
* On your subscription, assign Contributor role to your service principal
* Install MetaMask extension on Chrome

## Leader deployment
1. Login in to MetaMask and create an [account](https://medium.com/publicaio/how-to-create-a-metamask-account-e6d0ef156176). 
2. Download Ethereum POA template from [here](https://github.com/Azure/AzureStack-QuickStart-Templates/blob/master/Blockchain_PoA/common/mainTemplate.json)
3. On Azure Stack portal, create a custom deployment by using the downloaded template
4. Use the following parameter values:

| Parameter Name | Value                                    |
|----------------|:----------------------------------------:|
| location       | Location of your Azure Stack environment |
| isJoiningExistingNetwork | False - This should be false for leader deployment |
| regionCount | 1 - This is always 1 for Azure Stack |
| authType | password or sshPublicKey |
| adminUserName | Username of your Linux admin account |
| adminPassword | Password of your Linux admin account |
| adminSSHKey | You can use SSH Keys instead of password to access your Linux account |
| ethereumNetworkID | Arbitary value less than 2147483647 |
| consortiumMemberID | The ID associated with each member of the consortium network. This ID should be unique in the network |
| ethereumAdminPublicKey | Ethereum account address that is used for participating in PoA member management. Use address of the MetaMask account that was created on Step 1 |
| numVLNodesRegion | Number of load balanced validator nodes |
| vlNodeVMSize | Size of the virtual machine for transaction nodes |
| vlStorageAccountType | Type of managed disks to create. Allowed values: Standard_LRS, Premium_LRS |
| consortiumDataURL | N/A for leader deployment |
| publicRPCEndpoint | True - This should be True for Azure Stack environments | 
| enableSshAccess | Enables or Disables the Network Security Group rule to allow SSH port access | 
| servicePrincipalId | Service principal ID | 
| servicePrincipalSecret | Service principal secret | 
| endpointFqdn | Azure Stack environment FQDN | 
| tenantId | Azure stack tenant ID |
| deployUsingPublicIP | True | 
| isAdfs | Set to True if using template on ADFS environment |
| certKeyVaultId | Only for ADFS environments - The ID of the KeyVault that holds ADFS service principal certificate |
| certSecretUrl | Only for ADFS environments - The URL of the secret that holds ADFS service principal certificate | 


## Member deployment 
1. Login in to MetaMask and create an [account](https://medium.com/publicaio/how-to-create-a-metamask-account-e6d0ef156176). 
2. Go to leader's resource group deployments. From the deployments list click on Microsoft.Template deployment and go to Outputs section and save CONSORTIUM_DATA_URL value.  
3. Download Ethereum POA template from [here](https://github.com/Azure/AzureStack-QuickStart-Templates/blob/master/Blockchain_PoA/common/mainTemplate.json)
4. On Azure Stack portal, create a custom deployment by using the downloaded template
5. Use the following parameter values:

| Parameter Name | Value                                    |
|----------------|:----------------------------------------:|
| location       | Location of your Azure Stack environment |
| isJoiningExistingNetwork | True - This should be true for joining member deployment |
| authType | password or sshPublicKey |
| adminUserName | Username of your Linux admin account |
| adminPassword | Password of your Linux admin account |
| adminSSHKey | You can use SSH Keys instead of password to access your Linux account |
| ethereumNetworkID | Same as leader Network ID |
| consortiumMemberID | The ID associated with each member of the consortium network. This ID should be unique in the network |
| ethereumAdminPublicKey | Ethereum account address that is used for participating in PoA member management. Use address of the MetaMask account that was created on Step 1 |
| numVLNodesRegion | Number of load balanced validator nodes |
| vlNodeVMSize | Size of the virtual machine for transaction nodes |
| vlStorageAccountType | Type of managed disks to create. Allowed values: Standard_LRS, Premium_LRS |
| consortiumDataURL | ConsortiumDataURL from leader deployment output from step 2 |
| publicRPCEndpoint | True - This should be True for Azure Stack environments | 
| enableSshAccess | Enables or Disables the Network Security Group rule to allow SSH port access | 
| servicePrincipalId | Service principal ID | 
| servicePrincipalSecret | Service principal secret | 
| endpointFqdn | Azure Stack environment FQDN | 
| tenantId | Azure stack tenant ID |
| deployUsingPublicIP | True | 
| isAdfs | Set to True if using template on ADFS environment |
| certKeyVaultId | Only for ADFS environments - The ID of the KeyVault that holds ADFS service principal certificate |
| certSecretUrl | Only for ADFS environments - The URL of the secret that holds ADFS service principal certificate |  

## Troubleshoot deployment issues
To review the deployment logs for errors/failure :
1. Using the Azure Stack tenant portal locate the load balancer in the resource group where you deploy the consortium member and click it to open its blade.
2. Select "Inbound NAT rules"
3. Pick the IP address of any of the VMSS instances and make note of the port from "SERVICE" column.
4. Using an SSH console app such as Putty connect to it using the user name and password you provided in the input parameters. Default user name is "adminuser". 
5. There are three log files that are generated as part of Ethereum POA deployment:
    - Ethereum Deployment log located at /var/log/deployment/config.log
    - Parity (Blockchain Application) log located at /var/log/parity/parity.log
    - Admin website log located at /var/log/adminsite/etheradmin.log