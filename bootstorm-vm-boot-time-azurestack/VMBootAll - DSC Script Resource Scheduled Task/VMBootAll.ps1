#
# Copyright="?Microsoft Corporation. All rights reserved."
#
Configuration ConfigureVMBootAll
{
	param (
		[Parameter(Mandatory)]
		[string]$AzureUserName,
		[Parameter(Mandatory)]
		[string]$AzurePassword,
        [Parameter(Mandatory)]
		[string]$AzureApplicationId = "https://azurestack.local-api/",
		[Parameter(Mandatory)]
		[string]$TenantId = "7ea3e2b7-334d-4083-807b-fa2000faa9b8",
		[Parameter(Mandatory)]
		[string]$VMName,
		[Parameter(Mandatory)]
		[int32]$VMCount,
		[Parameter(Mandatory)]
		[string]$VMAdminUserName,
		[Parameter(Mandatory)]
		[string]$VMAdminPassword,
		[Parameter(Mandatory)]
		[string]$AzureStorageAccount
	)

	# Turn off private firewall
	netsh advfirewall set privateprofile state off
	# Get full path and name of the script being run
	$PSPath = $PSCommandPath;

	# DSC Script Resource - VM Bootstorm
	Script VMBAll
	{
		TestScript = { $false }

		GetScript = { return @{}}

		SetScript = {
			$azureUserName = $using:AzureUserName;
			$azurePassword = $using:AzurePassword;
            $applicationId = $using:AzureApplicationId;
			$tenant = $using:TenantId;
			$vmName = $using:VMName;
			$vmCount = $using:VMCount;
			# Needed for scheduled task to run with no logged-in user
			$vmAdminUserName = $using:VMAdminUserName;
			$vmAdminPassword = $using:VMAdminPassword;
			$storageAccount = $using:AzureStorageAccount;
			$psPath = $using:PSPath;

			# Ignore server certificate errors to avoid https://api.azurestack.local/ certificate error
			add-type @"
			using System.Net;
			using System.Security.Cryptography.X509Certificates;
			public class TrustAllCertsPolicy : ICertificatePolicy {
				public bool CheckValidationResult(
					ServicePoint srvPoint, X509Certificate certificate,
					WebRequest request, int certificateProblem) {
					return true;
				}
			}
"@
			[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
			Write-Warning -Message "CertificatePolicy set to ignore all server certificate errors"

			# Import Azure Resource Manager PS module if already present
			try {
				Write-Host "Importing Azure RM";
				Import-AzureRM;
			}
			# Install Azure Resource Manager PS module
			catch {
				Write-Host "Cannot import Azure RM module, proceeding with installation";
	
				# Suppress prompts
				$ConfirmPreference = 'None';

				# Install AzureRM
				Get-PackageProvider -Name nuget -ForceBootstrap –Force;
				Install-Module Azure –repository PSGallery –Force -Confirm:0;
				Install-Module AzureRM –repository PSGallery –Force -Confirm:0;
				Install-AzureRm;
				try {
					Write-Host "Importing Azure RM";
					Import-AzureRM;
				} 
				catch {
					Write-Host "Cannot import Azure RM module after installation of AzureRM module";
				}
			}
			#Import-DscResource -ModuleName 'PSDesiredStateConfiguration';

			# Disable Azure Data Collection
			Disable-AzureDataCollection -ErrorAction Ignore;

			$psScriptDir = Split-Path -Parent -Path $psPath;
			$psScriptName = "VMBootAllScript.ps1";
			$psScriptPath = "$psScriptDir\$psScriptName";
			$action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument "& $psScriptPath -azureUserName $azureUserName -azurePassword $azurePassword -azureApplicationId $applicationId -tenant $tenant -vmName $vmName -vmCount $vmCount -azureStorageAccount $storageAccount";
			$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2);
			$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd
			Unregister-ScheduledTask -TaskName "VMBootAll" -Confirm:0 -ErrorAction Ignore;
			Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "VMBootAll" -Description "VM Bootstorm" -User $vmAdminUserName -Password $vmAdminPassword -RunLevel Highest;
		}
	}	
}
