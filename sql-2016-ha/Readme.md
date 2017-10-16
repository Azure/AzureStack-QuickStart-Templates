# Create Two SQL Server 2016 SP1 VMs in always-on mode with SQL Authentication.

This template deploys two SQL Server 2016 SP1 Enterprise/ Developer instances in the Always On Availability Group using the PowerShell DSC Extension. It creates the following resources:

+	A network security group
+	A Virtual Network
+	Four Storage Accounts (One for AD, One for SQL, One for File Share witness and One for VM diagnostic)
+ 	Four public IP address (One for AD, Two for each SQL VM and One for Public LB bound to SQL Always On Listener)
+	One external load balancer for SQL VMs with Public IP bound to SQL always On Listener
+	One VM (WS2016) configured as Domain Controller for a new forest with a single domain
+	Two VM (WS2016) configured as SQL Server 2016 SP1 Enterprise/ Developer and clustered.
+	One VM (WS2016) configured as File Share Witness for the cluster.

## Notes

The images used to create this deployment are:

+	AD - Windows Server 2016 Image
+	SQL Server - SQL Server 2016 SP1 on Windows Server 2016 Image
+	SQL IAAS Extension 1.2.18
+	Latest DSC Extension (2.26.0 or higher)

# Configuration

+	Each SQL VMs will have two 128GB data disks.
+	The template configures the SQl instances with contained database authentication set to true.
+	The DNS suffic for public IP addresses (for ASDK: azurestack.external)