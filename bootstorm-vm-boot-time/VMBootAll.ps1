[DscLocalConfigurationManager()]
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
	VMBootAll -UserName $AzureAdApplicationId -Passwd $AzureAdApplicationPassword -Tenant $TenantId -VmName $VMName -VmCount $VMCount -StorageAccount $AzureStorageAccount
}

function VMBootAll
{
	param (
		[string]$userName,
		[string]$passwd,
		[string]$tenant,
		[string]$vmName,
		[int32]$vmCount,
		[string]$storageAccount
	)

	# Turn off private firewall
	netsh advfirewall set privateprofile state off

	# Import Azure Resource Manager PS module if already present
	try {
		Write-Host "Importing Azure RM"
		Import-AzureRM
	}
	# Install Azure Resource Manager PS module
	catch {
		Write-Host "Cannot import Azure RM module, proceeding with installation"
		
		# Suppress prompts
		$ConfirmPreference = 'None'

		# Install AzureRM
		Get-PackageProvider -Name nuget -ForceBootstrap –Force;
		Install-Module Azure –repository PSGallery –Force -Confirm:0;
		Install-Module AzureRM –repository PSGallery –Force -Confirm:0;
		Install-AzureRm;
	}

	# Authenticate to azure using ad application
	$pw = ConvertTo-SecureString -AsPlainText -Force -String $passwd;
	$pscred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $userName,$pw;
	if($pscred -eq $null) {
		Write-Host "Powershell Credential object is null. Cannot proceed.";
		return;
	}
	$cred = Get-Credential -Credential $pscred;
	if($cred -eq $null) {
		Write-Host "Get-Credential returned null. Cannot proceed.";
		return;
	}
	Add-AzureRmAccount -Credential $cred -ServicePrincipal -Tenant $tenant
	#Switch-AzureMode AzureResourceManager

	# Get VMs
	$vms = Get-AzureRmVM | Where {$_.Name -match $vmName}
	
	# Wait timeout retry count
	$numberOfRetries = 3

	# Wait for all VMs are deployed
	$noOfRetries = $numberOfRetries
	$noOfDeployedVMs = 0
	while(($noOfRetries -gt 0) -and ($noOfDeployedVMs -lt $vmCount)) {
		Start-Sleep -Seconds 120
		$noOfDeployedVMs = 0
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
		Write-Host "Requested number $vmCount of VMs are not deployed. Currently $noOfDeployedVMs VMs are deployed."
	}

	$resourceGroupName = $null
	# Turn off all VMs (except jump box VM which stores results)
	foreach($vm in $vms) {
		# All VMs except jump box VM
		if($vm.Name -match "[0-9]$") {
			$_date = Get-Date -Format hh:mmtt
			Write-Host Turning off VM $vm.Name in parallel at $_date -F Yellow
			#Stop-AzureRmVM -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Force
			Start-Job -ScriptBlock {
				param($_vmName,$_resourceGroupName,$userName,$passwd,$tenant)

				$pw = ConvertTo-SecureString -AsPlainText -Force -String $passwd;
				$pscred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $userName,$pw;
				if($pscred -eq $null) {
					Write-Host "Powershell Credential object is null. Cannot proceed.";
					return;
				}
				$cred = Get-Credential -Credential $pscred;
				if($cred -eq $null) {
					Write-Host "Get-Credential returned null. Cannot proceed.";
					return;
				}
				Add-AzureRmAccount -Credential $cred -ServicePrincipal -Tenant $tenant;

				Stop-AzureRmVM -Name $_vmName -ResourceGroupName $_resourceGroupName -Force;

			} -ArgumentList $vm.Name,$vm.ResourceGroupName,$userName,$passwd,$tenant
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
		Write-Host "$noOfRunningVMs VMs failed to turn off out of $vmCount VMs."
	}
	else {
		Write-Host All VMs are turned off
	}

	# Boot all VMs at the same time
	foreach($vm in $vms) {
		# All VMs except jump box VM
		if($vm.Name -match "[0-9]$") {
			$_date = Get-Date -Format hh:mmtt
			Write-Host Booting VM $vm.Name at $_date -F Yellow
			#Invoke-Command -ComputerName localhost -AsJob -ScriptBlock {
			Start-Job -ScriptBlock {
				param($_vmName,$_resourceGroupName,$userName,$passwd,$tenant)

				$pw = ConvertTo-SecureString -AsPlainText -Force -String $passwd;
				$pscred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $userName,$pw;
				if($pscred -eq $null) {
					Write-Host "Powershell Credential object is null. Cannot proceed.";
					return;
				}
				$cred = Get-Credential -Credential $pscred;
				if($cred -eq $null) {
					Write-Host "Get-Credential returned null. Cannot proceed.";
					return;
				}
				Add-AzureRmAccount -Credential $cred -ServicePrincipal -Tenant $tenant

				$_ret = Start-AzureRmVM -Name $_vmName -ResourceGroupName $_resourceGroupName;

				# Get VM Boot Time (Ignore NULL values)
				#$_statusBootEndTime = (Get-AzureRmVm -Name $_vmName -ResourceGroupName $_resourceGroupName -Status).Statuses | Select Time | ? {$_.Time -ne $null};
				#$_vmBootResult.VMBootEndTime = $_statusBootEndTime.Time.DateTime

				# Create custom vm boot result object
				$_vmBootResult = "" | Select-Object VMName, VMBootStartTime, VMBootEndTime, VMBootTimeInSeconds;
				$_vmBootResult.VMName = ($_vmName).Trim();
				$_vmBootResult.VMBootStartTime = ([DateTimeOffset]$_ret.StartTime).DateTime;
				$_vmBootResult.VMBootEndTime = ([DateTimeOffset]$_ret.EndTime).DateTime;
				$_vmBootResult.VMBootTimeInSeconds = [float]($_vmBootResult.VMBootEndTime - $_vmBootResult.VMBootStartTime).TotalSeconds;
				return $_vmBootResult;

			} -ArgumentList $vm.Name,$vm.ResourceGroupName,$userName,$passwd,$tenant
		}
	}
		
	# Wait for background jobs
	$jobs = Get-Job | ? {$_.State -eq "Running"}
	while($jobs.Count -gt 0)
	{
		Start-Sleep -Seconds 15
		$jobs = Get-Job | ? {$_.State -eq "Running"}
	}
	
	# Receive results
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

		echo "----------------------------------------------------------" > $vmbootResultFile
		echo "VM Name `t`tVM Boot Time (sec)" >> $vmbootResultFile
		echo "----------------------------------------------------------" >> $vmbootResultFile

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

				Write-Host "$_vmName `t`t$_vmBootTime"
				echo "$_vmName `t`t$_vmBootTime" >> $vmbootResultFile

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

		Write-Host "----------------------------------------------------------"
		Write-Host "$_vmBootTimeCount Azure A1-sized VMs cold booted in $_vmBootTimeAbsolute seconds at an average start time $_vmBootTimeAvg seconds/VM"
		Write-Host "----------------------------------------------------------"
		Write-Host "$_vmBootTimeCount A1 VMs in $_vmBootTimeAbsolute sec @ $_vmBootTimeAvg sec/VM"
		Write-Host "----------------------------------------------------------"

		echo "----------------------------------------------------------" >> $vmbootResultFile
		echo "$_vmBootTimeCount Azure A1-sized VMs cold booted in $_vmBootTimeAbsolute seconds at an average start time $_vmBootTimeAvg seconds/VM" >> $vmbootResultFile
		echo "----------------------------------------------------------" >> $vmbootResultFile
		echo "$_vmBootTimeCount A1 VMs in $_vmBootTimeAbsolute sec @ $_vmBootTimeAvg sec/VM" >> $vmbootResultFile
		echo "----------------------------------------------------------" >> $vmbootResultFile
	}
	else {
		Write-Host "Failed to get VM boot results"
		echo "Failed to get VM boot results" >> $vmbootResultFile
	}
	Publish-AzureRmVMDscConfiguration -ResourceGroupName $resourceGroupName -ConfigurationPath $vmbootResultFile -StorageAccountName $storageAccount -SkipDependencyDetection -Force;
}