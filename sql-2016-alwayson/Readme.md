# Create a two node SQL Server Always On Cluster with SQL 2016 on Windows Server 2016

This template deploys two SQL Server Enterprise, Standard or Developer instances in an Always On Availability Group. It creates the following resources:

* A network security group
* A virtual network
* Four storage accounts (One for AD, One for SQL, One for File Share witness and One for VM diagnostic)
* Four public IP address (One for AD, Two for each SQL VM and One for Public LB bound to SQL Always On Listener)
* One external load balancer for SQL VMs with Public IP bound to the SQL Always On listener
* One VM (WS2016) configured as Domain Controller for a new forest with a single domain
* Two VM (WS2016) configured as SQL Server 2016 SP1 or SP2 Enterprise/Standard/Developer and clustered (must use the marketplace images)
* One VM (WS2016) configured as File Share Witness for the cluster
* One Availability Set containing the SQL and FSW 2016 VMs

## Notes

The marketplace images used to create this deployment are:

* Windows Server 2016 Datacenter Image (for AD and FSW VMs)
* SQL Server 2016 SP1 or SP2 on Windows Server 2016 Image (Enterprise, Standard or Developer)
* Latest SQL IaaS Extension 1.2.30
* Latest DSC Extension (2.76.0, or higher)
* Latest Custom Script Extension for Windows (1.9.1, or higher)

## Configuration

* Each SQL VMs will have two data disks of up to 1TiB each
* The SQL VMs and the file share witness will be configured in an Availability Set (fault domains:3, update domains:5 - ASDK will automatically use 1,1)
* The template configures the SQL instances with contained database authentication set to true.
* The *external* DNS suffix for public IP addresses (ASDK default: azurestack.external)
