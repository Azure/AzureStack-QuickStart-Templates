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

UPDATE: 2022-10-23
* This template was updated to support selecting Windows 2016 Server, Windows 2019 Server or Windows 2022 Server for AD and SOFS cluster and SQL2019 on Windows 2019 Server or SQL2016 on Windows 2016 Server for the SQL cluster
* Files modified:
  * azuredeploy.json
    * To add the new SKU selection parameter for AD and SOFS cluster
    * To add the new Offer selection parameter for SQL cluster
  * azuredeploy.parameters.json
    * To add the new SKU parameter for AD and SOFS cluster
    * To add the new Offer parameter for SQL cluster
  * nestedtemplates\deploy-ad.json
    * To change the SKU parameter to allow selection
  * nestedtemplates\deploy-s2d-cluster.json
    * To change the SKU parameter to allow selection
  * nestedtemplates\deploy-sql-cluster.json
    * To change the ImageOffer parameter to allow selection
  * dsc\config-s2d.ps1\ConfigS2D.ps1
    * Changed EnableS2D to a DSCResource and added DSCResource with logic to retry when running the Enable-ClusterStorageSpacesDirect command (the command was changed from Enable-ClusterS2D)
    * The command Enable-ClusterS2D was changed to Enable-ClusterStorageSpacesDirect due to Enable-ClusterS2D deprecation
  * dsc\config-s2d.ps1\xFailOverCluster\DSCResources\MicrosoftAzure_xCluster\MicrosoftAzure_xCluster.psm1
    * On Set-TargetResource function to hande multiple executions of the Set-TargetResource and to prevent DSC from trying to execute Start-Cluster
  * dsc\config-sql.ps1\xSQL\DSCResources\MicrosoftAzure_xSqlServer\MicrosoftAzure_xSqlServer.psm1
    * Added support for SQL 2019 (MSSQL15) when settings the data and log files registry keys and setting the variables with the data and log files path
  * dsc\config-sql.ps1\xSQL\DSCResources\MicrosoftAzure_xSQLServerSettings\MicrosoftAzure_xSQLServerSettings.psm1
    * Added support for SQL 2019 (MSSQL15) when settings the data and log files registry keys and setting the variables with the data and log files path
  * dsc\config-sql.ps1\xFailOverCluster\DSCResources\MicrosoftAzure_xCluster\MicrosoftAzure_xCluster.psm1
    * On Set-TargetResource function to hande multiple executions of the Set-TargetResource and to prevent DSC from trying to execute Start-Cluster

This template uses Azure Stack Marketplace images. These need to be available on your Azure Stack instance:

* One of the possible Windows images (for AD and File Server VMs):
  * Windows Server 2016 Datacenter Core
  * Windows Server 2016 Datacenter
  * Windows Server 2019 Datacenter Core
  * Windows Server 2019 Datacenter
  * Windows Server 2022 Datacenter Core
  * Windows Server 2022 Datacenter
* One of the accepted SQL Server images (For SQL Cluster):
  * SQL Server 2016 SP2 on Windows Server 2016 (Enterprise)
  * SQL Server 2019 on Windows Server 2019 (Enterprise)
* Latest SQL IaaS Extension 1.3.x (currently 1.3.20710)
* Latest PowerShell Desired State Configuration Extension (currently 2.77.0.0)

## Parameters

| Parameter Name | Description | Type | Default Value
| --- | --- | --- | ---
| OSBaseVersion | SKU for AD and SOFS cluster Windows images | string | 2019-Datacenter-Core
| OSSQLVersion | Offer SQL cluster images | string | sql2019-ws2019
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
