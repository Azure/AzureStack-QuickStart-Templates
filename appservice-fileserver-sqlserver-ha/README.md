# Create HA Infrastructure for an AppServices deployment

This template will deploy all the infrastructure required for Azure Stack AppServices installation. The goal of the template is to simplify the deployment of the AppService Resource Provider and is therefore intended to be deployed into the Default Provider Subscription. Storage and Network configuration for deployment are included in the main template and may need to be adjusted according to your needs.

 It creates the following resources:

* A virtual network with required subnets 
* Network security groups for file server, SQL server and AD subnets
* Storage accounts for VM disks and cluster cloud witness
* One internal load balancer for SQL VMs with private IP bound to the SQL Always On listener
* Two VM (WS2016Core) configured as Domain Controllers for a new forest with a single domain
* Two VM (WS2016Core) configured as Storage Spaces Direct File share cluster 
* Three Availability Sets, for AD, Fileserver cluster and SQL cluster 

# Deploying the AppService Resource Provider

As stated the goal of this template is to deploy the infrastructure needed to support the App Service Resource Provider so this should be deployed before running the AppService installer.

* Check the template meets any requirements you may have on VNET address space and storage sizing
* Deploy this template using the Default Provider Subscription
* Create a new Resource Group 
* Make a note of the outputs from this template they will be needed when installing AppService
* When installing AppService be sure to select the option to deploy to an existing VNET
* Details of File Server and SQL server endpoints & accounts can be found in the outputs noted 
* After AppService deployment is complete manually back up bot the metering and hosting databases and add them to the availability group. 
* By default, the AppService Controller VM(s) have public IP addresses update the Controller NSG to allow RDP access, the SQL servers can be accessed from here on default IP addresses of 10.0.1.4 and 10.0.1.5

## Notes

This template uses Azure Stack Marketplace images. These need to be available on your Azure Stack instance:

* Windows Server 2016 Datacenter Core Image (for AD and File Server VMs)
* SQL Server 2016 SP2 on Windows Server 2016 (Enterprise)
* Latest SQL IaaS Extension 1.2.x (currently 1.2.30)
* Latest PowerShell Desired State Configuration Extension (currently 2.76.0)

## Parameters

| Parameter Name | Description | Type | Default Value
| --- | --- | --- | ---
| namePrefix | prefix to be used in resource naming | string | aps
| domainVmSize | VM size for AD VMs | string | Standard_DS1_v2
| filServerVmSize | VM size for file server VMs | string | Standard_DS2_v2
| sqlVmSize | VM size for SQL VMs | string | Standard_DS2_v2
| domainName | dns domain name of new domain | string | Appsvc.local
| adminUsername | Username for domain admin account | string | appsvcadmin
| adminPassword | password for domain admin account | secure string |
| fileShareOwnerUserName | Username for the file share owner account | string | FileShareOwner
| fileShareOwnerPassword | password for file share owner account | secure string |
| fileShareUserUserName | Username for the file share user account | string | FileShareUser
| fileShareUserPassword | password for domain admin account | secure string |
| sqlServerServiceAccountUserName | Username for SQL service account | string | svcSQL
| sqlServerServiceAccountPassword | password for SQL service account | secure string |
| sqlLogin | Username for the SQL login | string | sqlsa
| sqlLoginPassword | password for SQL login account | secure string |
| sofsName | Name of the Scale-out File Server | string | sofs01
| shareName | Name of the Fileshare | string | WebSites
| artifactsLocation | Blob store where all deployment artifacts are stored | string |  https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/master/appservice-fileserver-sqlserver-ha  
| artifactsLocationSasToken | SAS token for artifact location if required | secure string |  
| location | location to be used for the deployment | string |

## Outputs

| Parameter Name | Description 
| --- | --- 
| FileSharePath | FQDN of the file server 
| FileShareOwner | Name of File Share Owner Account 
| FileShareUser | Name of File Share User Account 
| SQLserver | Name of SQL account 
| SQLUser | Name of SQL Server 
