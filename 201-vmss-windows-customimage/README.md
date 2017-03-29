# Deploy a VM Scale Set based on a Windows Custom Image

This template deploys a VM Scale Set from a user provided Windows Custom Image

The template allows a URL to a custom image to be provided as a parameter at run time. The custom image should be contained in a storage account which is in the same location as the VM Scale Set is created in, in addtion the storage account which contains the image should also be under the same subscription that the scale set is being created in.

PARAMETER RESTRICTIONS
======================

vmssName must be 3-10 characters in length. It should also be globally unique across all of AzureStack. If it isn't globally unique, it is possible that this template will still deploy properly, but we don't recommend relying on this pseudo-probabilistic behavior.
instanceCount must be 20 or less. VM Scale Set supports upto 100 VMs and one should add more storage accounts to support this number.
