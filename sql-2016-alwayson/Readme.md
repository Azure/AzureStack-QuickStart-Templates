# Create a two node SQL Server Always On Cluster with SQL 2016 on Windows Server 2016

This template deploys two SQL Server Enterprise, Standard or Developer instances in an Always On Availability Group. It creates the following resources:

* A network security group
* A virtual network
* Four storage accounts (One for AD, One for SQL, One for File Share witness and One for VM diagnostic)
* Four public IP address (One for AD, One for each SQL VM and One for Public LB bound to SQL Always On Listener)
* One external load balancer for SQL VMs with Public IP bound to the SQL Always On listener
* One VM (WS2016) configured as Domain Controller for a new forest with a single domain
* Two VM (WS2016) configured as SQL Server 2016 SP1 or SP2 Enterprise/Standard/Developer (must use the marketplace images)
* One VM (WS2016) configured as File Share Witness for the cluster
* Two Availability Sets, one containing the SQL and FSW 2016 VMs, the other containing the Domain Controller VM.

## Notes

This template uses Azure Stack Marketplace images. These need to be available on your Azure Stack instance:

* Windows Server 2016 Datacenter Image (for AD and FSW VMs)
* Choice of SQL Server 2016 SP1 or SP2 on Windows Server 2016 (Enterprise, Standard or Developer)
* Latest SQL IaaS Extension 1.2.x (currently 1.2.30)
* Latest DSC Extension (2.76.0, or higher)
* Latest Custom Script Extension for Windows (1.9.1, or higher)

## Configuration

* Each SQL VMs will have the number and size of data disks specified, of up to 1TiB each. The SQL extension will configured these into a single volume using Storage Spaces.
* The SQL VMs and the file share witness will be configured in an Availability Set
  * Integrated Systems (fault domains:3, update domains:5)
  * ASDK will automatically use fault domains:1, update domains:1)
* The template configures the SQL instances with contained database authentication set to true.
* The *external* DNS suffix for public IP addresses (ASDK default: azurestack.external)

## Parameters

| Parameter Name | Description | Type | Default Value
| --- | --- | --- | ---
| _artifactsLocation | Blob store where all deployment artifacts are stored | string |  https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/master/sql-2016-alwayson
| adminUsername | Admin user for new VMs and domain | string | localadmin 
| adminPassword | Password used for the new admin | securestring | (must be specified)
| adVMSize | VM size for the domain controller | string* | Standard_D2_v2
| witnessVMSize | VM size for the file share witness | string* | Standard_D1_v2
| domainName | Name of the new AD domain | string | fabrikam.local
| dnsSuffix | Name of the Azure Stack instance's external domain | string |
| virtualNetworkAddressRange | Address range for new VNET in CIDR format  | string | 10.0.0.0/16
| staticSubnet | Range of addresses from the virtualNetworkAddressRange for static IP allocation | string | 10.0.0.0/24
| sqlSubnet | Address range used by the SQL & FSW VMs | string | 10.0.1.0/26
| adPDCNICIPAddress | IP address for the AD VM | string | 10.0.0.250
| deploymentPrefix | DNS prefix for the public IP addresses | string | aodns
| virtualNetworkName | Name of the virtual network | string | sqlhaVNET
| sqlServerServiceAccountUserName | The SQL Server Service Account name | string | sqlservice
| sqlServerServiceAccountPassword | Password for the service account | secure string |
| sqlAuthUserName | SQL Server Admin user | string | sqlsa
| sqlAutPassword | Password for the SQL Server Admin | secure string |
| sqlStorageAccountName | Name for the SQL Storage Account | string | derived from resource group name
| sqlStorageAccountType | Standard or Premium Storage | string | Premium_LRS
| sqlServerOffer | Name of the SQL Offer | string* | SQL2016SP2-WS2016
| sqlServerSku | Name of the SKU | string* | Enterprise
| sqlVMSize | Size of the SQL Server VMs | string * | Standard_DS2_v2
| sqlAOAGName | SQL Always On Availability Group Name | string | sqlaa-ag
| sqlAOListenerName | SQL Always On listener name | string | derived from the resource group name
| sqlAOListenerPort | TCP port number used by the listener | string | 1433
| workloadType | SQL VM Workload (GENERAL, OLTP, DW) | string* | GENERAL
| vmDiskSize | SQL data disk size (128, 256, 512, 1023) | string | 128
| numberOfSqlVMDisks | Number of SQL data disks per server | int | 2
| sampleDatabaseName | Sample HA database created during deployment | string | AutoHa-sample
| autoPatchingDay | Day of the week to download and apply patches | string* | Sunday
| autoPatchingStartHour | Hour to start patching process | string* | 2

* parameter has a list of allowed values; please refer to the template.