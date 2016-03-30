#
# Copyright="?Microsoft Corporation. All rights reserved."
#

param (
	[Parameter(Mandatory)]
    [string]$AzureUsername,
	[Parameter(Mandatory)]
    [string]$AzurePassword,
	[string]$AdResourceID = "",
	[Parameter(Mandatory)]
	[string]$TenantId,
	[Parameter(Mandatory)]
	[string]$VMName,
	[Parameter(Mandatory)]
	[int32]$VMCount,
	[Parameter(Mandatory)]
	[string]$AzureStorageAccount
)

function VMBootAll {
	
	# Azure uses AzureAdApplicationId and AzureAdApplicationPassword values as AzureUserName and AzurePassword parameters respectively
	# AzureStack uses tenant UserName and Password values as AzureUserName and AzurePassword parameters respectively
	$azureUsername = $AzureUsername;
	$azurePassword = $AzurePassword;
	# Azure uses "null" or "" blank value, AzureStack uses "https://azurestack.local-api/" value for AdResourceID parameter
    $adResourceID = $AdResourceID;
	$tenant = $TenantId;
	$vmName = $VMName;
	$vmCount = $VMCount;
	$storageAccount = $AzureStorageAccount;

	# Local file storage location
	$localPath = "$env:SystemDrive";

	# Log file
	$logFileName = "VMWorkloadController.log.ps1";
	$logFilePath = "$localPath\$logFileName";
	
	# Turn off private firewall
	netsh advfirewall set privateprofile state off;
	
	# PS Credentials
	$pw = ConvertTo-SecureString -AsPlainText -Force -String $azurePassword;
	$pscred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $azureUsername,$pw;
	if($pscred -eq $null) {
		Write-Host "Powershell Credential object is null. Cannot proceed.";
		return;
	}
	$azureCreds = Get-Credential -Credential $pscred;
	if($azureCreds -eq $null) {
		Write-Host "Get-Credential returned null. Cannot proceed.";
		return;
	}
	
	######################
	### AZURE RM SETUP ###
	######################
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
		"Importing Azure RM" | Out-File $logFilePath -Encoding ASCII -Append;
		Import-AzureRM;
	}
	# Install Azure Resource Manager PS module
	catch {
		Write-Host "Cannot import Azure RM module, proceeding with installation" -ForegroundColor Yellow;
		"Cannot import Azure RM module, proceeding with installation" | Out-File $logFilePath -Encoding ASCII -Append;
	
		# Suppress prompts
		$ConfirmPreference = 'None';

		# Install AzureRM
		Get-PackageProvider -Name nuget -ForceBootstrap –Force;
		Install-Module Azure –repository PSGallery –Force -Confirm:0;
		Install-Module AzureRM –repository PSGallery –Force -Confirm:0;
		Install-AzureRm;
	}

    # AzureStack
	if($adResourceID -ne "")
	{
		# Authenticate to AzureStack
		Add-AzureRmEnvironment -Name 'AzureStack' -ActiveDirectoryEndpoint ("https://login.windows.net/$tenant/") -ActiveDirectoryServiceEndpointResourceId $adResourceID `
			-ResourceManagerEndpoint ("https://api.azurestack.local/") -GalleryEndpoint ("https://gallery.azurestack.local:30016/") -GraphEndpoint "https://graph.windows.net/" -StorageEndpoint "azurestack.local";
		if($azureCreds -eq $null) {
			Write-Host "Powershell Credential object is null. Cannot proceed." -ForegroundColor Red;
			"Powershell Credential object is null. Cannot proceed." | Out-File $logFilePath -Encoding ASCII -Append;
			return;
		}
		$azureAcc = Add-AzureRmAccount -EnvironmentName 'AzureStack' -Verbose -Credential $azureCreds;
	}
	# AzureCloud
	else {
		# Authenticate to Azure using AzureAdApplication
		if($azureCreds -eq $null) {
			Write-Host "Powershell Credential object is null. Cannot proceed." -ForegroundColor Red;
			"Powershell Credential object is null. Cannot proceed." | Out-File $logFilePath -Encoding ASCII -Append;
			return;
		}
		"Authenticating Azure RM Account" | Out-File $logFilePath -Encoding ASCII -Append;
		Add-AzureRmAccount -Credential $azureCreds -ServicePrincipal -Tenant $tenant;
	}
	
	##############################
	### VM PRE-BOOTSTORM SETUP ###
	##############################
	# Get VMs
	"Getting VMs" | Out-File $logFilePath -Encoding ASCII -Append;
	$vms = Get-AzureRmVM | Where {$_.Name -match $vmName}

	# Wait timeout retry count
	$numberOfRetries = 10

	# Wait for all VMs are deployed
	$noOfRetries = $numberOfRetries
	$noOfDeployedVMs = 0
	while(($noOfRetries -gt 0) -and ($noOfDeployedVMs -lt $vmCount)) {
		Start-Sleep -Seconds 120
		$noOfDeployedVMs = 0
		Write-Host "Getting VMs...retrying $noOfRetries";
		"Getting VMs...retrying $noOfRetries" | Out-File $logFilePath -Encoding ASCII -Append;
		$vms = Get-AzureRmVM | Where {$_.Name -match $vmName}
		foreach($vm in $vms) {
			# All VMs except jump box VM
			if($vm.Name -match "[0-9]$") {
				$noOfDeployedVMs += 1
			}
		}
		$noOfRetries -= 1
	}
	if($noOfDeployedVMs -lt $vmCount) {
		Write-Host "Only $noOfDeployedVMs out of $vmCount user requested VMs are deployed." -ForegroundColor Yellow;
		"Only $noOfDeployedVMs out of $vmCount user requested VMs are deployed." | Out-File $logFilePath -Encoding ASCII -Append;
	}
	else {
		Write-Host "All $noOfDeployedVMs out of $vmCount user requested VMs are deployed." -ForegroundColor Green;
		"All $noOfDeployedVMs out of $vmCount user requested VMs are deployed." | Out-File $logFilePath -Encoding ASCII -Append;
	}

	$resourceGroupName = $null
	# Turn off all VMs (except jump box VM which stores results)
	foreach($vm in $vms) {
		$_vmName = $vm.Name;
		# All VMs except jump box VM
		if($_vmName -match "[0-9]$") {
			$_date = Get-Date -Format hh:mmtt
			Write-Host "Turning off VM $_vmName in parallel at $_date" -F Yellow
			"Turning off VM $_vmName in parallel at $_date" | Out-File $logFilePath -Encoding ASCII -Append;
			Start-Job -ScriptBlock {
				param($_vmName,$_resourceGroupName,$adResourceID,$tenant,$azureUsername,$azurePassword)

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

				$pw = ConvertTo-SecureString -AsPlainText -Force -String $azurePassword;
				$pscred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $azureUsername,$pw;
				if($pscred -eq $null) {
					Write-Host "Powershell Credential object is null. Cannot proceed.";
					return;
				}
				$azureCreds = Get-Credential -Credential $pscred;

				# AzureStack
				if($adResourceID -ne "")
				{
					# Authenticate to AzureStack
					Add-AzureRmEnvironment -Name 'AzureStack' -ActiveDirectoryEndpoint ("https://login.windows.net/$tenant/") -ActiveDirectoryServiceEndpointResourceId $adResourceID `
						-ResourceManagerEndpoint ("https://api.azurestack.local/") -GalleryEndpoint ("https://gallery.azurestack.local:30016/") -GraphEndpoint "https://graph.windows.net/" -StorageEndpoint "azurestack.local";
					if($azureCreds -eq $null) {
						Write-Host "Powershell Credential object is null. Cannot proceed.";
						"Powershell Credential object is null. Cannot proceed." | Out-File $logFilePath -Encoding ASCII -Append;
						return;
					}
					$azureAcc = Add-AzureRmAccount -EnvironmentName 'AzureStack' -Verbose -Credential $azureCreds;
				}
				# AzureCloud
				else {
					# Authenticate to Azure using AzureAdApplication
					if($azureCreds -eq $null) {
						Write-Host "Powershell Credential object is null. Cannot proceed.";
						"Powershell Credential object is null. Cannot proceed." | Out-File $logFilePath -Encoding ASCII -Append;
						return;
					}
					"Authenticating Azure RM Account" | Out-File $logFilePath -Encoding ASCII -Append;
					Add-AzureRmAccount -Credential $azureCreds -ServicePrincipal -Tenant $tenant;
				}

				Stop-AzureRmVM -Name $_vmName -ResourceGroupName $_resourceGroupName -Force;

			} -ArgumentList $vm.Name,$vm.ResourceGroupName,$adResourceID,$tenant,$azureUsername,$azurePassword
			$resourceGroupName = $vm.ResourceGroupName
		}
	}
	# Wait for background jobs
	$jobs = Get-Job | ? {$_.State -eq "Running"}
	while($jobs.Count -gt 0)
	{
		Start-Sleep -Seconds 15
		$jobs = Get-Job | ? {$_.State -eq "Running"}
	}

	# Clear background jobs
	Get-Job | Remove-Job -Force -Confirm:0

	# Check if all VMs are deallocated (i.e. turned off)
	$noOfRetries = $numberOfRetries
	$noOfRunningVMs = [int32]::MaxValue
	while(($noOfRetries -gt 0) -and ($noOfRunningVMs -gt 0)) {
		Start-Sleep -Seconds 120
		$noOfRunningVMs = 0
		foreach($vm in $vms) {
			# All VMs except jump box VM
			if($vm.Name -match "[0-9]$") {
				$vmStatus = Get-AzureRmVM -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Status
				$isVmRunning = $vmStatus.Statuses[1].Code.Contains("running")
				if($isVmRunning -eq $true){
					$noOfRunningVMs += 1
				}
			}
		}
		$noOfRetries -= 1
	}
	if($noOfRunningVMs -gt 0) {
		Write-Host "$noOfRunningVMs out of $vmCount VMs failed to turn off." -ForegroundColor Yellow;
		"$noOfRunningVMs out of $vmCount VMs failed to turn off." | Out-File $logFilePath -Encoding ASCII -Append;
	}
	else {
		Write-Host "All $vmCount VMs are turned off";
		"All $vmCount VMs are turned off" | Out-File $logFilePath -Encoding ASCII -Append;
	}

	####################
	### VM BOOTSTORM ###
	####################
	# Boot all VMs at the same time
	foreach($vm in $vms) {
		$_vmName = $vm.Name;
		# All VMs except jump box VM
		if($_vmName -match "[0-9]$") {
			$_date = Get-Date -Format hh:mmtt
			Write-Host "Booting VM $_vmName at $_date" -F Yellow
			"Booting VM $_vmName at $_date" | Out-File $logFilePath -Encoding ASCII -Append;

			Start-Job -ScriptBlock {
				param($_vmName,$_resourceGroupName,$adResourceID,$tenant,$azureUsername,$azurePassword,$logFilePath)

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

				$pw = ConvertTo-SecureString -AsPlainText -Force -String $azurePassword;
				$pscred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $azureUsername,$pw;
				if($pscred -eq $null) {
					Write-Host "Unable to create PSCrednetial using user provided credentials. Cannot proceed.";
					"Unable to create PSCrednetial using user provided credentials. Cannot proceed." | Out-File $logFilePath -Encoding ASCII -Append;
					return;
				}
				$azureCreds = Get-Credential -Credential $pscred;
				if($azureCreds -eq $null) {
					Write-Host "Unable to create crednetial object using user provided credentials. Cannot proceed.";
					"Unable to create crednetial object using user provided credentials. Cannot proceed." | Out-File $logFilePath -Encoding ASCII -Append;
					return;
				}

                # AzureStack
				if($adResourceID -ne "")
				{
					# Authenticate to AzureStack using Azure Account crednetials and given tenantID, resourceID
					Add-AzureRmEnvironment -Name 'AzureStack' -ActiveDirectoryEndpoint ("https://login.windows.net/$tenant/") -ActiveDirectoryServiceEndpointResourceId $adResourceID `
						-ResourceManagerEndpoint ("https://api.azurestack.local/") -GalleryEndpoint ("https://gallery.azurestack.local:30016/") -GraphEndpoint "https://graph.windows.net/" -StorageEndpoint "azurestack.local";
					$azureAcc = Add-AzureRmAccount -EnvironmentName 'AzureStack' -Verbose -Credential $azureCreds;
				}
				# AzureCloud
				else {
					# Authenticate to Azure using AzureAdApplication and given tenantID
					"Authenticating Azure RM Account" | Out-File $logFilePath -Encoding ASCII -Append;
					Add-AzureRmAccount -Credential $azureCreds -ServicePrincipal -Tenant $tenant;
				}

				# Get VM Boot Start Time
				$_statusBootStartTime = Get-Date;

				Start-AzureRmVM -Name $_vmName -ResourceGroupName $_resourceGroupName;

				# Get VM Boot End Time (Ignore NULL values of Time)
				$_statusBootEndTime = (Get-AzureRmVm -Name $_vmName -ResourceGroupName $_resourceGroupName -Status).Statuses | Select Time | ? {$_.Time -ne $null};

				# Create custom vm boot result object
				$_vmBootResult = "" | Select-Object VMName, VMBootStartTime, VMBootEndTime, VMBootTimeInSeconds;
				$_vmBootResult.VMName = ($_vmName).Trim();
				$_vmBootResult.VMBootStartTime = ([DateTimeOffset]$_statusBootStartTime).DateTime;
				$_vmBootResult.VMBootEndTime = ([DateTimeOffset]$_statusBootEndTime.Time.DateTime).DateTime;
				$dbgText = "DEBUG: VM $_vmName boot start time: " + $_vmBootResult.VMBootStartTime + ", boot end time: " + $_vmBootResult.VMBootEndTime;
				$dbgTest | Out-File $logFilePath -Encoding ASCII -Append;
				$_vmBootResult.VMBootTimeInSeconds = [float]($_vmBootResult.VMBootEndTime - $_vmBootResult.VMBootStartTime).TotalSeconds;
				return $_vmBootResult;

			} -ArgumentList $vm.Name,$vm.ResourceGroupName,$adResourceID,$tenant,$azureUsername,$azurePassword,$logFilePath
		}
	}
	
	# Wait for background jobs
	$jobs = Get-Job | ? {$_.State -eq "Running"}
	while($jobs.Count -gt 0)
	{
		Start-Sleep -Seconds 15
		$jobs = Get-Job | ? {$_.State -eq "Running"}
	}

	# Receive job results
	$vmbootResults = @()
	foreach($job in Get-Job) { $vmbootResults += ,(Receive-Job -Job $job) }

	# Clear background jobs
	Get-Job | Remove-Job -Force -Confirm:0

	# Display boot results
	$vmbootResultFile = "$env:SystemDrive\VMBootAllResult.log.ps1"

	if($vmbootResults.Count -gt 0) {

		Write-Host "----------------------------------------------------------"
		Write-Host "VM Name `t`tVM Boot Time (sec)"
		Write-Host "----------------------------------------------------------"

		"----------------------------------------------------------" | Out-File $vmbootResultFile -Encoding ASCII;
		"VM Name `t`tVM Boot Time (sec)" | Out-File $vmbootResultFile -Encoding ASCII -Append;
		"----------------------------------------------------------" | Out-File $vmbootResultFile -Encoding ASCII -Append;

		$_vmBootFailedCount = 0
		$_vmBootTimeCount = 0
		$_vmBootTimeSum = 0.0
		$_vmBootTimeAvg = 0.0
		$_vmBootTimeAbsolute = 0.0
		$_vmBootTimeAbsoluteStart = Get-Date 
		$_vmBootTimeAbsoluteEnd = (Get-Date).AddDays(-30)

		foreach($vmbootResult in $vmbootResults) {
			if($vmbootResult -ne $null)
			{
				# Remove extra array object with properties Environment,Account,Tenant,Subscription,CurrentStorageAccount
				$vmbootResult = $vmbootResult | ? { $_.GetType().ToString() -contains "System.Management.Automation.PSCustomObject" }

				$_vmName = $vmbootResult.VMName
				$_vmBootTime = "{0:N3}" -f [float]($vmbootResult.VMBootTimeInSeconds)
				if(($_vmBootTime -le 0) -and ($_vmBootTime -ge [Int32]::MaxValue)) {
					"Skipping invalid boot time $_vmBootTime for VM $_vmname" | Out-File $logFilePath -Encoding ASCII -Append;
					$_vmBootFailedCount++;
					continue;
				}
				
				Write-Host "$_vmName `t`t$_vmBootTime"
				"$_vmName `t`t$_vmBootTime" | Out-File $vmbootResultFile -Encoding ASCII -Append;

				$_vmBootTimeSum += ([double]::Parse($vmbootResult.VMBootTimeInSeconds))
				$_vmBootTimeCount += 1
				if($_vmBootTimeAbsoluteStart -gt $vmbootResult.VMBootStartTime) {
					$_vmBootTimeAbsoluteStart = $vmbootResult.VMBootStartTime
				}
				if($_vmBootTimeAbsoluteEnd -lt $vmbootResult.VMBootEndTime) {
					$_vmBootTimeAbsoluteEnd = $vmbootResult.VMBootEndTime
				}
			}
		}

		$_vmBootTimeAvg = "{0:N3}" -f [float]($_vmBootTimeSum/$_vmBootTimeCount)
		$_vmBootTimeAbsolute = "{0:N3}" -f [float](($_vmBootTimeAbsoluteEnd - $_vmBootTimeAbsoluteStart).TotalSeconds);

		Write-Host "----------------------------------------------------------";
		Write-Host "$_vmBootTimeCount Azure A1-sized VMs cold booted in $_vmBootTimeAbsolute seconds at an average start time $_vmBootTimeAvg seconds/VM" -ForegroundColor Green;
		Write-Host "----------------------------------------------------------";
		Write-Host "$_vmBootTimeCount A1 VMs in $_vmBootTimeAbsolute sec @ $_vmBootTimeAvg sec/VM" -ForegroundColor Green;
		Write-Host "----------------------------------------------------------";
		if($_vmBootFailedCount -gt 0){
			Write-Host "Failed to get boot time for $_vmBootFailedCount VMs";
			Write-Host "----------------------------------------------------------";
		}

		"----------------------------------------------------------" | Out-File $vmbootResultFile -Encoding ASCII -Append;
		"$_vmBootTimeCount Azure A1-sized VMs cold booted in $_vmBootTimeAbsolute seconds at an average start time $_vmBootTimeAvg seconds/VM" | Out-File $vmbootResultFile -Encoding ASCII -Append;
		"----------------------------------------------------------" | Out-File $vmbootResultFile -Encoding ASCII -Append;
		"$_vmBootTimeCount A1 VMs in $_vmBootTimeAbsolute sec @ $_vmBootTimeAvg sec/VM" | Out-File $vmbootResultFile -Encoding ASCII -Append;
		"----------------------------------------------------------" | Out-File $vmbootResultFile -Encoding ASCII -Append;
		if($_vmBootFailedCount -gt 0){
			"Failed to get boot time for $_vmBootFailedCount VMs" | Out-File $vmbootResultFile -Encoding ASCII -Append;
			"----------------------------------------------------------" | Out-File $vmbootResultFile -Encoding ASCII -Append;
		}
	}
	else {
		Write-Host "Failed to get VM boot results" -ForegroundColor Red;
		"Failed to get VM boot results" | Out-File $logFilePath -Encoding ASCII -Append;
		"Failed to get VM boot results" | Out-File $vmbootResultFile -Encoding ASCII -Append;
	}
	Publish-AzureRmVMDscConfiguration -ResourceGroupName $resourceGroupName -ConfigurationPath $vmbootResultFile -StorageAccountName $storageAccount -SkipDependencyDetection -Force;
	Publish-AzureRmVMDscConfiguration -ResourceGroupName $resourceGroupName -ConfigurationPath $logFilePath -StorageAccountName $storageAccount -SkipDependencyDetection -Force -ErrorAction SilentlyContinue;
}
VMBootAll
 