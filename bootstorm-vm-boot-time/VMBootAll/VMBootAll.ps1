#
# Copyright="?Microsoft Corporation. All rights reserved."
#
Configuration ConfigureVMBootAll
{
	param (
		[Parameter(Mandatory)]
		[string]$AzureAccountUsername,
		[Parameter(Mandatory)]
		[string]$AzureAccountPassword,
		[string]$AdResourceID = "",
		[Parameter(Mandatory)]
		[string]$TenantId,
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
		TestScript = { (Get-ScheduledTask -TaskName "VMBootAll" -ErrorAction SilentlyContinue) -ne $null; }

		GetScript = { return @{"TaskName" = "VMBootAll";} }

		SetScript = {
			# Azure uses AzureAdApplicationId and AzureAdApplicationPassword values as AzureUserName and AzurePassword parameters respectively
			# AzureStack uses tenant UserName and Password values as AzureUserName and AzurePassword parameters respectively
			$azureUsername = $using:AzureAccountUsername;
			$azurePassword = $using:AzureAccountPassword;
			# Azure uses "null" or "" blank value, AzureStack uses "https://azurestack.local-api/" value for AdResourceID parameter
            $adResourceID = $using:AdResourceID;
			if($adResourceID -eq "null"){
				$adResourceID = ""
			}
			$tenant = $using:TenantId;
			$vmName = $using:VMName;
			$vmCount = $using:VMCount;
			# Needed for scheduled task to run with no logged-in user
			$vmAdminUserName = $using:VMAdminUserName;
			$vmAdminPassword = $using:VMAdminPassword;
			$storageAccount = $using:AzureStorageAccount;
			$psPath = $using:PSPath;

			# AzureStack
			if($applicationId -ne "")
			{
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
			}

			# Import Azure Resource Manager PS module if already present
			try {
				Write-Host "Importing Azure RM";
				Import-AzureRM;
			}
			# Install Azure Resource Manager PS module
			catch {
				# Suppress prompts
				$ConfirmPreference = 'None';

				Write-Host "Cannot import Azure RM module, proceeding with installation";

				# Install AzureRM
				try {
					Get-PackageProvider -Name nuget -ForceBootstrap –Force;
					Install-Module Azure –repository PSGallery –Force -Confirm:0;
					Install-Module AzureRM –repository PSGallery –Force -Confirm:0;
					Install-AzureRm;
				}
				catch {
					Write-Host "Installation of Azure RM module failed."
				}

				# Import AzureRM
				try {
					Write-Host "Importing Azure RM";
					Import-AzureRM;
				} 
				catch {
					Write-Host "Cannot import Azure RM module after installation of AzureRM module";
				}
			}

			# Disable Azure Data Collection
			try {
				Disable-AzureRmDataCollection -ErrorAction Ignore;
			}
			catch {
				Write-Host "Disable-AzureRmDataCollection has thrown an exception";
			}

			$psScriptDir = Split-Path -Parent -Path $psPath;
			$psScriptName = "VMBootAllScript.ps1";
			$psScriptPath = "$psScriptDir\$psScriptName";
			$action = $null;
			# AzureStack
			if($adResourceID -ne "")
			{
				$action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument "& $psScriptPath -azureUserName $azureUsername -azurePassword $azurePassword -adResourceID $adResourceID -tenant $tenant -vmName $vmName -vmCount $vmCount -azureStorageAccount $storageAccount" -ErrorAction Ignore;
			}
			else {
				$action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument "& $psScriptPath -azureUserName $azureUsername -azurePassword $azurePassword -tenant $tenant -vmName $vmName -vmCount $vmCount -azureStorageAccount $storageAccount" -ErrorAction Ignore;
			}
			$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -ErrorAction Ignore;
			$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd -ErrorAction Ignore;
			Unregister-ScheduledTask -TaskName "VMBootAll" -Confirm:0 -ErrorAction Ignore;
			Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "VMBootAll" -Description "VM Bootstorm" -User $vmAdminUserName -Password $vmAdminPassword -RunLevel Highest -ErrorAction Ignore;
		}
	}	
}
