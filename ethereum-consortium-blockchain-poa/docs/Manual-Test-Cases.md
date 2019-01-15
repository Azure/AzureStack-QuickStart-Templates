# Manual Test Cases 


## Test Case : Reimage nodes and verify the status of the POA network
Objective: Reimage ( upgrade the operating system) of the virtual machines and verify that the POA network still functions as expected

	1. Deploy a POA network
	2. Reimage the VMSS (Vitrual machine) using API call provided at https://docs.microsoft.com/en-us/rest/api/compute/virtualmachinescalesets/reimage/
	3. Verify that the POA network continues to function after the VMs have been reimaged

## Test Case: Restart nodes and verify the status of the POA network
Objective : Restart the nodes and make sure that the POA network continues to function

	1. Deploy a POA network and verify that its operational
	2. In azure portal , select the Virtual Machine Scale Set for a specific region and click on Restart to restart the virtual machines
	3. Verify that the POA network continues to function after the VMS have been restarted

## Test Case: Verify a node is able to acquire a new lease after lease expiration
Objective: Break the lease on node identity and verify that the network continues to function

	1. Deploy a POA network and make sure that its operational
	2. In azure portal, go to the storage account for the deployed network and break the lease on one or more of the lease id files ( passphrase -x.json)
	3. Verify that the VMS were able to renew the broken leases and the network continues to normally operate

## Test Case : Docker containers resiliency
Objective: Manually kill docker containers and verify that the containers are restarted

	1. Deploy a POA network and make sure that its operational
	2. SSH into one of the VMS and kill the docker container one by one using docker kill command
    3. Verify that the containers are restated and the network continues to function normally
