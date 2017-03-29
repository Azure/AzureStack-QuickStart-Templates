# Manually change the number of VMs in an existing VM Scale Set

This template allows you to manually scale in or out the number of VMs in an existing Scale Set. The capacity specified will be the new capacity of the scale set. 

The VM size in this template is set to Standard_D1. If you are doing a scale operation on a VM Scale Set with different sized VMs, you will need to change this parameter. I.e. make sure the "sku" property in this template matches the "sku" you originally deployed your Scale Set with. Otherwise, either this deployment will fail (when the VM size belongs to a different family), or VMs will be created with a different size to the existing VMs.

PARAMETER RESTRICTIONS
======================

existingVMSSName must be the name of an EXISTING VM Scale Set

vmSku must be the same size as the VM size of your EXISTING VM Scale Set