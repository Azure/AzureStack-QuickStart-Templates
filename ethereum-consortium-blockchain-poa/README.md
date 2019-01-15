# Deploy Ethereum Proof-Of-Authority on Azure Stack
This template deploys all of the resources required for Ethereum POA.   

## Prerequisites
* Download following images from the Marketplace:
    - Ubuntu Server 16.04 LTS (any version)
    - Custom Script for Linux 2.0

* Create a service principal and save it's ID and secret
* On your subscription, assign Contributor role to your service principal
* Install MetaMask extension on Chrome

## Leader deployment
1. Login in to MetaMask and create an [account](https://medium.com/publicaio/how-to-create-a-metamask-account-e6d0ef156176). 
2. Download Ethereum POA template from [here](https://github.com/Azure/AzureStack-QuickStart-Templates/blob/master/Blockchain_PoA/common/mainTemplate.json)
3. On Azure Stack portal, create a custom deployment by using the downloaded template
4. Use the following parameter values:

| Parameter Name | Value                                    |
|----------------|:----------------------------------------:|
| Location       | Location of your Azure Stack environment |
| isJoiningExistingNetwork | False - This should be false for leader deployment |
| regionCount | 1 - This is always 1 for Azure Stack |
| Location_1 | Location of your Azure Stack environment |
| Location_2 | N/A (don't change the default value) |
| Location_3 | N/A (don't change the default value) |
| Location_4 | N/A (don't change the default value) |
| Location_5 | N/A (don't change the default value) |
| AuthType | password |
| AdminUserName | Username of your Linux admin account |
| AdminPassword | Password of your Linux admin account |
| AdminSSHKey | You can use SSH Keys instead of password to access your Linux account |
| EthereumNetworkID | Arbitary value less than 2147483647 |
| ConsortiumMemberID | The ID associated with each member of the consortium network. This ID should be unique in the network |
| EthereumAdminPublicKey | Ethereum account address that is used for participating in PoA member management. Use address of the MetaMask account that was created on Step 1 |
| DeployUsingPublicIP | True |
| NumVLNodesRegion | Number of load balanced validator nodes |
| VlNodeVMSize | Standard_D1_v2 |
| VlStorageAccountType | Standard_LRS |
| ConnectionSharedKey | N/A | 
| ConsortiumMemberGatewayId | N/A |
| ConsortiumDataURL | N/A for leader deployment |
| TransactionPermissioningContract | N/A |
| PublicRPCEndpoint | True | 
| OmsDeploy | False | 
| omsWorkspaceId | N/A | 
| omsPrimaryKey | N/A | 
| omsLocation | N/A | 
| emailAddress | N/A | 
| enableSshAccess | True | 
| azureStackDeployment | True | 
| servicePrincipalId | Service principal ID | 
| servicePrincipalSecret | Service principal secret | 
| endpointFqdn | Azure Stack environment FQDN | 
| tenantId | Azure stack tenant ID | 


## Member deployment 
1. Login in to MetaMask and create an [account](https://medium.com/publicaio/how-to-create-a-metamask-account-e6d0ef156176). 
2. Go to leader's resource group deployments. From the deployments list click on Microsoft.Template deployment and go to Outputs section and save CONSORTIUM_DATA_URL value.  
3. Download Ethereum POA template from [here](https://github.com/Azure/AzureStack-QuickStart-Templates/blob/master/Blockchain_PoA/common/mainTemplate.json)
4. On Azure Stack portal, create a custom deployment by using the downloaded template
5. Use the following parameter values:

| Parameter Name | Value                                    |
|----------------|:----------------------------------------:|
| Location       | Location of your Azure Stack environment |
| isJoiningExistingNetwork | True - This should be true for joining member deployment |
| regionCount | 1 - This is always 1 for Azure Stack |
| Location_1 | Location of your Azure Stack environment |
| Location_2 | N/A (don't change the default value) |
| Location_3 | N/A (don't change the default value) |
| Location_4 | N/A (don't change the default value) |
| Location_5 | N/A (don't change the default value) |
| AuthType | password |
| AdminUserName | Username of your Linux admin account |
| AdminPassword | Password of your Linux admin account |
| AdminSSHKey | You can use SSH Keys instead of password to access your Linux account |
| EthereumNetworkID | Same as leader Network ID |
| ConsortiumMemberID | The ID associated with each member of the consortium network. This ID should be unique in the network |
| EthereumAdminPublicKey | Ethereum account address that is used for participating in PoA member management. Use address of the MetaMask account that was created on Step 1 |
| DeployUsingPublicIP | True |
| NumVLNodesRegion | Number of load balanced validator nodes |
| VlNodeVMSize | Standard_D1_v2 |
| VlStorageAccountType | Standard_LRS |
| ConnectionSharedKey | N/A | 
| ConsortiumMemberGatewayId | N/A |
| ConsortiumDataURL | ConsortiumDataURL from leader deployment output from step 2 |
| TransactionPermissioningContract | N/A |
| PublicRPCEndpoint | True | 
| OmsDeploy | False | 
| omsWorkspaceId | N/A | 
| omsPrimaryKey | N/A | 
| omsLocation | N/A | 
| emailAddress | N/A | 
| enableSshAccess | True | 
| azureStackDeployment | True | 
| servicePrincipalId | Service principal ID | 
| servicePrincipalSecret | Service principal secret | 
| endpointFqdn | Azure Stack environment FQDN | 
| tenantId | Azure stack tenant ID | 

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