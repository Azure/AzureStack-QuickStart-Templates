# Deploy a VM Scale Set of Windows VMs

This template allows you to deploy a VM Scale Set of Windows VMs. It creates 5 storage accounts so the VM Scale set and can be conviniently scaled to 100 VMs. It uses the latest patched version of several Windows versions. To connect from the load balancer to a VM in the scale set, you would go to the AzureStack Portal, find the load balancer of your scale set, examine the NAT rules, then connect using the NAT rule you want. For example, if there is a NAT rule on port 50000, you could RDP on port 50000 of the public IP to connect to that VM. Similarly if something is listening on port 80 we can connect to it using port 80.

PARAMETER RESTRICTIONS
======================

vmssName must be 3-10 characters in length. It should also be globally unique across all of AzureStack. If it isn't globally unique, it is possible that this template will still deploy properly, but we don't recommend relying on this pseudo-probabilistic behavior.
instanceCount must be 100 or less.
