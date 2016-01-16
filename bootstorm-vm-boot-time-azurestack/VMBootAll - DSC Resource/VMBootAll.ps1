#
# Copyright="?Microsoft Corporation. All rights reserved."
#
Configuration ConfigureVMBootAll
{
	param (
		[Parameter(Mandatory)]
		[string]$AzureAdApplicationId,
		[Parameter(Mandatory)]
		[string]$AzureAdApplicationPassword,
		[Parameter(Mandatory)]
		[string]$TenantId,
		[Parameter(Mandatory)]
		[string]$VMName,
		[Parameter(Mandatory)]
		[int32]$VMCount,
		[Parameter(Mandatory)]
		[string]$AzureStorageAccount
	)

	# Turn off private firewall
	netsh advfirewall set privateprofile state off

	Import-DscResource -ModuleName BootAllVMs

	Node $env:COMPUTERNAME
    {
		BootAllVMs BAVMs
		{
			UserName = $AzureAdApplicationId 
			Passwd = $AzureAdApplicationPassword 
			Tenant = $TenantId 
			VmName = $VMName 
			VmCount = $VMCount 
			StorageAccount = $AzureStorageAccount
		}
	}

	LocalConfigurationManager 
    {
        RebootNodeIfNeeded = $false
    }
	
}
