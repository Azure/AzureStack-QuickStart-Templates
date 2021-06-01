#
# Copyright="?Microsoft Corporation. All rights reserved."
#

param (
    [Parameter(Mandatory)]
    [string]$AzureUsername,
    [Parameter(Mandatory)]
    [string]$AzurePassword,
    [Parameter(Mandatory)]
    [string]$TenantId,
    [Parameter(Mandatory)]
    [string]$Location,
    [Parameter(Mandatory)]
    [string]$VMName,
    [Parameter(Mandatory)]
    [int32]$VMCount,
    [Parameter(Mandatory)]
    [string]$AzureStorageAccount,
    [Parameter(Mandatory)]
    [string]$AzureStorageAccessKey,
    [Parameter(Mandatory)]
    [string]$AzureStorageEndpoint,
    [Parameter(Mandatory)]
    [string]$AzureSubscription
)

"Importing Azure module" | Tee-Object -FilePath $logFilePath -Append
Import-Module AzureRm -ErrorAction Stop | Out-Null

function VMBootAll {

    # Azure uses AzureAdApplicationId and AzureAdApplicationPassword values as AzureUserName and AzurePassword parameters respectively
    # AzureStack uses tenant UserName and Password values as AzureUserName and AzurePassword parameters respectively
    $azureUsername = $AzureUsername
    $azurePassword = $AzurePassword
    $tenant = $TenantId
    $location = $Location
    $vmName = $VMName
    $vmCount = $VMCount
    $storageAccountName = $AzureStorageAccount
    $storageAccountKey = $AzureStorageAccessKey
    $storageEndpoint = $AzureStorageEndpoint

    # Local file storage location
    $localPath = "$env:SystemDrive\BootStorm"


    if((Get-Item -Path $localPath -ErrorAction SilentlyContinue) -eq $null) {
        "Creating result smb share $localPath" | Tee-Object -FilePath $logFilePath -Append
        New-Item -Path $localPath -Type Directory -Force -Confirm:0
    }

    $logDate = "$(Get-Date -Format "yyyy.MM.dd_HH.mm.ss")"
    $transcriptLog = "$localPath\BootStormTranscript_$logDate"
    Start-Transcript -Path $transcriptLog

    if((Get-SMBShare -Name smbshare -ErrorAction SilentlyContinue) -eq $null) {
        New-SMBShare -Path $localPath -Name BootStormResults -FullAccess Everyone
    }

    # Log file
    $logFileName = "VMBoot.log"
    $logFilePath = "$localPath\$logFileName"

    # Test status file
    $statusFilePath = "$($env:SystemDrive)\VMBootStatus.log"

    if(Test-Path $logFilePath) {
        "Log file $logFilePath already exists. Skipped text execution" | Tee-Object -FilePath $logFilePath -Append
        return
    }

    # Turn off private firewall
    netsh advfirewall set privateprofile state off

    # PS Credentials
    $pw = ConvertTo-SecureString -AsPlainText -Force -String $azurePassword
    $pscred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $azureUsername,$pw
    if($pscred -eq $null) {
        "Powershell Credential object is null. Cannot proceed." | Tee-Object -FilePath $logFilePath -Append
        return
    }
    $azureCreds = Get-Credential -Credential $pscred
    if($azureCreds -eq $null) {
        "Get-Credential returned null. Cannot proceed." | Tee-Object -FilePath $logFilePath -Append
        return
    }

    #TODO Query the ARM endpoint or parameterize it
    $resourceManagerEndpoint = $("https://management.$storageEndpoint".ToLowerInvariant())
    $endptres = Invoke-RestMethod "${ResourceManagerEndpoint}/metadata/endpoints?api-version=1.0"

    $activeDirectoryServiceEndpointResourceId = $($endptres.authentication.audiences[0])
    $aadTenantId = $tenant
    $activeDirectoryEndpoint = $($endptres.authentication.loginEndpoint)
    $activeDirectoryEndpoint = $($endptres.authentication.loginEndpoint).TrimEnd("/") + "/"
    $galleryEndpoint = $endptres.galleryEndpoint
    $graphEndpoint = $endptres.graphEndpoint
    $storageEndpointSuffix="$($storageEndpoint)".ToLowerInvariant()
    $azureKeyVaultDnsSuffix="vault.$($storageEndpoint)".ToLowerInvariant()

    # Get AzureToken
    $resourceManagerEndpoint = $("https://management.$storageEndpoint".ToLowerInvariant())
    $endptres = Invoke-RestMethod "${ResourceManagerEndpoint}/metadata/endpoints?api-version=1.0"

    $activeDirectoryServiceEndpointResourceId = $($endptres.authentication.audiences[0])
    $aadTenantId = $tenant
    $activeDirectoryEndpoint = $($endptres.authentication.loginEndpoint).TrimEnd("/") + "/"
    $clientId = "1950a258-227b-4e31-a9cf-717495945fc2"

    $contextAuthorityEndpoint = ([System.IO.Path]::Combine($activeDirectoryEndpoint, $aadTenantId)).Replace('\','/')

    try
    {

        $authContext = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext($contextAuthorityEndpoint, $false)
        $userCredential = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.UserCredential($azureCreds.UserName, $azureCreds.Password)

        $azureToken = ($authContext.AcquireToken($activeDirectoryServiceEndpointResourceId, $clientId, $userCredential)).AccessToken

        if(!$azureToken)
        {
            "Error: Unable to generate Authorization token" | Tee-Object -FilePath $logFilePath -Append

            return;
        }

        # AzureStack
        # determine proper way to detect we are running on AzureStack
        if((IsAzureStack -Location $location) -eq $true) {
            # Authenticate to AzureStack
            try {
                $envName = "AzureStackCloud"

                Add-AzureRmEnvironment -Name ($envName) `
                        -ActiveDirectoryEndpoint ($activeDirectoryEndpoint) `
                        -ActiveDirectoryServiceEndpointResourceId ($activeDirectoryServiceEndpointResourceId) `
                        -ResourceManagerEndpoint ($resourceManagerEndpoint) `
                        -GalleryEndpoint ($galleryEndpoint) `
                        -GraphEndpoint ($graphEndpoint) `
                        -StorageEndpointSuffix ($storageEndpointSuffix) `
                        -AzureKeyVaultDnsSuffix ($azureKeyVaultDnsSuffix) | Out-Null

                Add-AzureRmAccount -EnvironmentName $envName -Credential $azureCreds -TenantId $aadTenantId | Out-Null
            }
            catch [Exception] {
                "Failed to authenticate with Azure Stack. Exception details $_" | Tee-Object -FilePath $logFilePath -Append
            }
        }
        # AzureCloud
        else {
            if($azureCreds -eq $null) {
                "Powershell Credential object is null. Cannot proceed." | Tee-Object -FilePath $logFilePath -Append
                return
            }
            # Authenticate to Azure using AzureAdApplication
            try {
                Add-AzureRmAccount -Credential $azureCreds -ServicePrincipal -Tenant $tenant
            }
            catch [Exception] {
                "Failed to authenticate with Azure. Exception details $_" | Tee-Object -FilePath $logFilePath -Append
            }
        }

        try  {
            "Subscription ID $AzureSubscription" | Tee-Object -FilePath $logFilePath -Append
            "Setting subscription" | Tee-Object -FilePath $logFilePath -Append
            Select-AzureRmSubscription -SubscriptionId $AzureSubscription | Tee-Object -FilePath $logFilePath -Append
        }
        catch {
            "Failed to select Azure subscription (id: $AzureSubscription)" | Tee-Object -FilePath $logFilePath -Append
            "Exception: $_" | Tee-Object -FilePath $logFilePath -Append
        }

        ##############################
        ### VM PRE-BOOTSTORM SETUP ###
        ##############################
        # Get VMs
        "Getting VMs" | Tee-Object -FilePath $logFilePath -Append

        $vms = Get-AzureRmVM | Where-Object {$_.Name -match $vmName}

        $resourceGroupName = $null
        # Turn off all VMs (except jump box VM which stores results)
        foreach($vm in $vms) {
            $_vmName = $vm.Name
            # All VMs except jump box VM
            if($_vmName -match "[0-9]$") {
                $_date = Get-Date -Format hh:mmtt
                $logFile = $localPath + "\VmBoot_" + $_vmName + ".log"
                "Turning off VM $_vmName in parallel at $_date" | Tee-Object -FilePath $logFilePath -Append

                Start-Job -ScriptBlock {
                    param($_vmName,$_resourceGroupName,$location,$logFile,$azureSubscription,$armEndpoint,$token)
                    $logDate = "$(Get-Date -Format "yyyy.MM.dd_HH.mm.ss")"
                    $transcriptLog = "$logFile_transcript_$logDate"
                    Start-Transcript -Path $transcriptLog
                    try {
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

                        $d = Get-Date
                        "$d Stopping VM $_vmName" | Tee-Object -FilePath $logFile -Append
                        try {
                            # Make the calls using REST and passing in token to avoid too many fast Auth calls
                            $stopAzureVM = @{
                                    Uri ='{0}/subscriptions/{1}/resourceGroups/{2}/providers/Microsoft.Compute/virtualMachines/{3}/powerOff?api-version=2015-06-15' `
                                        -f $armEndpoint, $azureSubscription, $_resourceGroupName, $_vmName
                                    Method = "POST"
                                    Headers = @{ "Authorization" = "Bearer " + $token }
                                    ContentType = "application/json"
                                }

                            "URI: $($stopAzureVM.Uri)" | Tee-Object -FilePath $logFile -Append

                            $result = Invoke-RestMethod @stopAzureVM >> $logFile

                        } catch {
                            "Failed to turn off $_vmName VM. Exception details $_" | Tee-Object -FilePath $logFile -Append
                        }
                        $d = Get-Date
                        "$d VM $_vmName Stopped" | Tee-Object -FilePath $logFile -Append
                    } catch {
                        "Unexpected exception turning off $_vmName VM. Exception details $_" | Tee-Object -FilePath $logFile -Append
                    } finally {
                        Stop-Transcript
                    }
                } -ArgumentList $_vmName,$vm.ResourceGroupName,$location,$logFile,$AzureSubscription,$resourceManagerEndpoint,$azureToken | Out-Null

                $resourceGroupName = $vm.ResourceGroupName
            }
        }

        $numberOfRetries = 60

        # Wait for background jobs
        $jobs = Get-Job | Where-Object {$_.State -eq "Running"}
        $noOfRetries = $numberOfRetries
        while(($jobs.Count -gt 0) -and ($noOfRetries -gt 0)) {
            "Waiting for VMs to all be stopped. $($jobs.Count) jobs left. Retries left: $noOfRetries" | Tee-Object -FilePath $logFilePath -Append
            Start-Sleep -Seconds 15
            $noOfRetries--
            $jobs = Get-Job | Where-Object {$_.State -eq "Running"}
        }
        "Done waiting for VMs to all be stopped." | Tee-Object -FilePath $logFilePath -Append

        # Clear background jobs
        Get-Job | Remove-Job -Force -Confirm:0

        # Check if all VMs are deallocated (i.e. turned off)
        $noOfRetries = $numberOfRetries
        [System.Collections.ArrayList]$runningVMs = $vms
        #1 VM = the controller VM
        while(($noOfRetries -gt 0) -and ($runningVMs.Count -gt 1)) {
            Start-Sleep -Seconds 30

            # All VMs except jump box VM
            [System.Collections.ArrayList]$removeArray = @()

            foreach($vm in $runningVMs) {
                if($vm.Name -match "[0-9]$") {
                    try {
                        "$(Get-Date -displayhint Time) Start Get-AzureRmVM on $($vm.Name)" | Tee-Object -FilePath $logFilePath -Append
                        $vmStatus = Get-AzureRmVM -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Status
                        "$(Get-Date -displayhint Time) End Get-AzureRmVM on $($vm.Name) : Status '$($vmStatus.Statuses[1].Code)'" | Tee-Object -FilePath $logFilePath -Append
                    } catch {
                        "Get-AzureRmVM on $($vm.Name) failed $_" | Tee-Object -FilePath $logFilePath -Append
                    }

                    $isVmRunning = $vmStatus.Statuses[1].Code.Contains("running")

                    if($isVmRunning -eq $false) {
                        $removeArray.Add($vm)
                    }
                }
            }

            foreach($vm in $RemoveArray) {
                $runningVMs.Remove($vm)
            }

            $RemoveArray.Clear()

            "Waiting for all VMs to no longer be running. Running VMs: $($runningVMs.Count). Retries left: $noOfRetries" | Tee-Object -FilePath $logFilePath -Append
            $noOfRetries -= 1
        }
        if($noOfRunningVMs -gt 0) {
            "$noOfRunningVMs out of $vmCount VMs failed to turn off." | Tee-Object -FilePath $logFilePath -Append
        }
        else {
            "All $vmCount VMs are turned off" | Tee-Object -FilePath $logFilePath -Append
        }

        # Get Token again incase it needs refreshing
        $authContext = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext($contextAuthorityEndpoint, $false)
        $userCredential = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.UserCredential($azureCreds.UserName, $azureCreds.Password)
        $azureToken = ($authContext.AcquireToken($activeDirectoryServiceEndpointResourceId, $clientId, $userCredential)).AccessToken

        ####################
        ### VM BOOTSTORM ###
        ####################
        # Boot all VMs at the same time
        foreach($vm in $vms) {
            $_vmName = $vm.Name
            # All VMs except jump box VM
            if($_vmName -match "[0-9]$") {
                $_date = Get-Date -Format hh:mmtt
                $logFile = $localPath + "\VmBoot_" + $_vmName + ".log"
                "Booting VM $_vmName at $_date" | Tee-Object -FilePath $logFilePath -Append

                Start-Job -ScriptBlock {
                    param($_vmName,$_resourceGroupName,$location,$logFile,$azureSubscription, $armEndpoint, $token)
                    $logDate = "$(Get-Date -Format "yyyy.MM.dd_HH.mm.ss")"
                    $transcriptLog = "$($logFile)_transcript_$($logDate)"
                    Start-Transcript -Path $transcriptLog
                    try {
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

                        # Get VM Boot Start Time
                        $_statusBootStartTime = Get-Date
                        "Starting boot at $_statusBootStartTime" | Tee-Object -FilePath $logFile -Append
                        try {
                            # Make the calls using REST and passing in token to avoid too many fast Auth calls
                            $startAzureVM = @{
                                    Uri ='{0}/subscriptions/{1}/resourceGroups/{2}/providers/Microsoft.Compute/virtualMachines/{3}/start?api-version=2015-06-15' `
                                        -f $armEndpoint, $azureSubscription, $_resourceGroupName, $_vmName
                                    Method = "POST"
                                    Headers = @{ "Authorization" = "Bearer " + $token }
                                    ContentType = "application/json"
                                }

                            "URI: $($startAzureVM.Uri)" | Tee-Object -FilePath $logFile -Append

                            $result = Invoke-RestMethod @startAzureVM >> $logFile

                        } catch [Exception] {
                            "Failed to turn on VM $_vmName Exception: $_" | Tee-Object -FilePath $logFile -Append
                        }
                        $_dateAfterBoot = Get-Date
                        "Boot succeeded at $_dateAfterBoot" | Tee-Object -FilePath $logFile -Append
                        # Get VM Boot End Time (Ignore NULL values of Time)

                        $numberOfRetries = 60
                        $retries = 0

                        do
                        {
                            "Waiting for boot.  Retry Count $retries" | Tee-Object -FilePath $logFile -Append

                            Start-Sleep -Seconds 60
                            $retries++

                            # Make the calls using REST and passing in token to avoid too many fast Auth calls
                            $getAzureVM = @{
                                    Uri ='{0}/subscriptions/{1}/resourceGroups/{2}/providers/Microsoft.Compute/virtualMachines/{3}?$expand=instanceView&api-version=2015-06-15' `
                                        -f $armEndpoint, $azureSubscription, $_resourceGroupName, $_vmName
                                    Method = "Get"
                                    Headers = @{ "Authorization" = "Bearer " + $token }
                                    ContentType = "application/json"
                                }

                            "URI: $($getAzureVM.Uri)" | Tee-Object -FilePath $logFile -Append

                            $result = Invoke-RestMethod @getAzureVM

                            $_statusBootEndTime = $result.Properties.InstanceView.Statuses[0].Time
                        } while(!$_statusBootEndTime -and $retries -lt $numberOfRetries)

                        # Create custom vm boot result object
                        $_vmBootResult = "" | Select-Object VMName, VMBootStartTime, VMBootEndTime, VMBootTimeInSeconds
                        $_vmBootResult.VMName = ($_vmName).Trim()
                        $_vmBootResult.VMBootStartTime = ([DateTimeOffset]$_statusBootStartTime).DateTime
                        $_vmBootResult.VMBootEndTime = ([DateTimeOffset]$_statusBootEndTime).DateTime
                        if($_vmBootResult.VMBootEndTime -gt $_vmBootResult.VMBootStartTime) {
                            $_vmBootResult.VMBootTimeInSeconds = [float]($_vmBootResult.VMBootEndTime - $_vmBootResult.VMBootStartTime).TotalSeconds
                        }
                        else {
                            $_vmBootResult.VMBootTimeInSeconds = 0
                            "VM boot end time is invalid for VM $_vmName" | Tee-Object -FilePath $logFile -Append
                        }
                    } catch {
                        "Unexpected exception starting VM $_vmName. $_" | Tee-Object -FilePath $logFile -Append
                    } finally {
                        Stop-Transcript
                    }
                    return $_vmBootResult

                } -ArgumentList $vm.Name,$vm.ResourceGroupName,$location,$logFile,$AzureSubscription,$resourceManagerEndpoint, $azureToken | Out-Null
            }
        }

        # Wait for background jobs
        $jobs = Get-Job | Where-Object {$_.State -eq "Running"}
        while($jobs.Count -gt 0) {
            "$($jobs.Count) VMs still booting" | Tee-Object -FilePath $logFilePath -Append
            Start-Sleep -Seconds 15
            $jobs = Get-Job | Where-Object {$_.State -eq "Running"}
        }

        # Receive job results
        $vmbootResults = @()
        foreach($job in Get-Job) { $vmbootResults += ,(Receive-Job -Job $job) }

        # Clear background jobs
        Get-Job | Remove-Job -Force -Confirm:0

        # Prepare storage context to upload results to Azure storage table
        "Azure ad resource id is $storageEndpoint" | Tee-Object -FilePath $logFilePath -Append

        "Azure storage endpoint $storageEndpoint is being used." | Tee-Object -FilePath $logFilePath -Append
        $storageContext = $null
        $storageTable = $null
        try {
            $storageContext = New-AzureStorageContext $storageAccountName -StorageAccountKey $storageAccountKey -Endpoint $storageEndpoint
            if($storageContext -eq $null) {
                "Azure Storage context is null." | Tee-Object -FilePath $logFilePath -Append
            }
            $storageTableName = "VMBootResults"

            # Retrieve the table if it already exists.
            try {
                $storageTable = Get-AzureStorageTable -Name $storageTableName -Context $storageContext -ErrorAction SilentlyContinue
                if($storageTable -ne $null) {
                    Remove-AzureStorageTable -Name $storageTableName -Context $storageContext -Force -ErrorAction SilentlyContinue
                }
            } catch {
                "Storage table $storageTableName does not exists. Creating a new table." | Tee-Object -FilePath $logFilePath -Append
            }

            # Create a new table if it does not exist.
            if ($storageTable -eq $null) {
                try {
                    $storageTable = New-AzureStorageTable -Name $storageTableName -Context $storageContext
                } catch [Exception] {
                    "Storage table $storageTableName cannot be created. Exception: $_" | Tee-Object -FilePath $logFilePath -Append

                    try {
                        $storageTable = New-AzureStorageTable -Name $storageTableName -Context $storageContext
                    } catch [Exception] {
                        "Storage table $storageTableName cannot be created. Exception: $_" | Tee-Object -FilePath $logFilePath -Append
                    }
                }
            }
        }
        catch {
            "Azure storage context cannot be created for a given storage account $storageAccountName" | Tee-Object -FilePath $logFilePath -Append
        }

        # Function to add a result row to the Azure Storage Table
        function Add-TableEntity() {
            [CmdletBinding()]
            param(
                $table,
                [String]$PartitionKey,
                [String]$RowKey,
                [String]$Value
            )

            if($table -eq $null) {
                "Value cannot be inserted into null table" | Tee-Object -FilePath $logFilePath -Append
            }

            $entity = New-Object -TypeName Microsoft.WindowsAzure.Storage.Table.DynamicTableEntity -ArgumentList $PartitionKey, $RowKey
            $entity.Properties.Add("Value", $Value)
            if($entity -eq $null) {
                "Entity cannot be created for partition key $PartitionKey and row $RowKey" | Tee-Object -FilePath $logFilePath -Append
            }

            $result = $table.CloudTable.Execute([Microsoft.WindowsAzure.Storage.Table.TableOperation]::Insert($entity))
            return $result
        }

        # Display boot results
        $vmbootResultFile = "$env:SystemDrive\VMBootResult.log"

        # Skip test if already executed
        if(Test-Path $vmbootResultFile -ErrorAction SilentlyContinue) {
            "Result file already exists. Skipping test execution." | Tee-Object -FilePath $logFilePath -Append
            return
        }

        if($vmbootResults.Count -gt 0) {

            "----------------------------------------------------------" | Tee-Object -FilePath $vmbootResultFile
            "VM Name `t`tVM Boot Time (sec)" | Tee-Object -FilePath $vmbootResultFile -Append
            "----------------------------------------------------------" | Tee-Object -FilePath $vmbootResultFile -Append

            $_vmBootFailedCount = 0
            $_vmBootTimeCount = 0
            $_vmBootTimeSum = 0.0
            $_vmBootTimeAvg = 0.0
            $_vmBootTimeAbsolute = 0.0
            $_vmBootTimeAbsoluteStart = Get-Date
            $_vmBootTimeAbsoluteEnd = (Get-Date).AddDays(-30)
            $_vmBootTimeMax = 0.0
            $_vmBootTimeMin = [float]::MaxValue
            $_executionId = Get-Date -Format yyyyMMdd_HHmm

            $vmResultIndex = 0
            foreach($vmbootResult in $vmbootResults) {
                if($vmbootResult -ne $null) {
                    # Remove extra array object with properties Environment,Account,Tenant,Subscription,CurrentStorageAccount
                    $vmbootResult = $vmbootResult | Where-Object { $_.GetType().ToString().Contains("System.Management.Automation.PSCustomObject") }

                    $_vmName = $vmbootResult.VMName
                    $_vmBootTime = ([double]::Parse($vmbootResult.VMBootTimeInSeconds))
                    $_vmBootTimeString = "{0:N0}" -f [float]($_vmBootTime)
                    $_vmBootTimeString = $_vmBootTimeString -replace ","
                    if(($_vmBootTime -le 0) -and ($_vmBootTime -ge [Int32]::MaxValue)) {
                        "Skipping invalid boot time $_vmBootTimeString for VM $_vmname" | Tee-Object -FilePath $logFilePath -Append
                        $_vmBootFailedCount++
                        continue
                    }

                    "$_vmName `t`t$_vmBootTimeString" | Tee-Object -FilePath $vmbootResultFile -Append

                    # Add vm boot results to the Azure storage table
                    if($storageTable -ne $null) {
                        try {
                            Add-TableEntity -Table $storageTable -PartitionKey $_executionId -RowKey $_vmName -Value $_vmBootTimeString
                        } catch {
                            Write-Verbose "Adding Azure storage table entry for row $vmResultIndex failed."
                            "Adding Azure storage table entry for row $vmResultIndex failed." | Tee-Object -FilePath $logFilePath -Append
                        }
                    }
                    else {
                        "Azure storage table object $storageTable is null" | Tee-Object -FilePath $logFilePath -Append
                    }

                    $_vmBootTimeSum += $_vmBootTime
                    $_vmBootTimeCount += 1
                    if($_vmBootTimeAbsoluteStart -gt $vmbootResult.VMBootStartTime) {
                        $_vmBootTimeAbsoluteStart = $vmbootResult.VMBootStartTime
                    }
                    if($_vmBootTimeAbsoluteEnd -lt $vmbootResult.VMBootEndTime) {
                        $_vmBootTimeAbsoluteEnd = $vmbootResult.VMBootEndTime
                    }
                    if($_vmBootTimeMax -lt $_vmBootTime) {
                        $_vmBootTimeMax = $_vmBootTime
                    }
                    if($_vmBootTimeMin -gt $_vmBootTime) {
                        $_vmBootTimeMin = $_vmBootTime
                    }
                }
                $vmResultIndex += 1
            }

            $_vmBootTimeAvg = "{0:N0}" -f [float]($_vmBootTimeSum/$_vmBootTimeCount)
            $_vmBootTimeAvg = $_vmBootTimeAvg -replace ","
            $_vmBootTimeAbsolute = "{0:N0}" -f [float](($_vmBootTimeAbsoluteEnd - $_vmBootTimeAbsoluteStart).TotalSeconds)
            $_vmBootTimeAbsolute = $_vmBootTimeAbsolute -replace ","
            $_vmBootTimeMax = "{0:N0}" -f [float]($_vmBootTimeMax)
            $_vmBootTimeMax = $_vmBootTimeMax -replace ","
            $_vmBootTimeMin = "{0:N0}" -f [float]($_vmBootTimeMin)
            $_vmBootTimeMin = $_vmBootTimeMin -replace ","
            "----------------------------------------------------------" | Tee-Object -FilePath $logFilePath -Append
            if($VMCount -gt $_vmBootTimeCount) {
                "$_vmBootTimeCount out of $VMCount Azure A1-sized VMs cold booted in $_vmBootTimeAbsolute seconds at an average start time $_vmBootTimeAvg seconds/VM." | Tee-Object -FilePath $logFilePath -Append
            }
            else {
                "$_vmBootTimeCount Azure A1-sized VMs cold booted in $_vmBootTimeAbsolute seconds at an average start time $_vmBootTimeAvg seconds/VM." | Tee-Object -FilePath $logFilePath -Append
            }

            "----------------------------------------------------------" | Tee-Object -FilePath $logFilePath -Append
            "Minimum vm boot time is $_vmBootTimeMin sec and maximum vm boot time is $_vmBootTimeMax sec" | Tee-Object -FilePath $logFilePath -Append
            "----------------------------------------------------------" | Tee-Object -FilePath $logFilePath -Append
            "$_vmBootTimeCount A1 VMs in $_vmBootTimeAbsolute sec @ $_vmBootTimeAvg sec/VM" | Tee-Object -FilePath $logFilePath -Append
            "----------------------------------------------------------" | Tee-Object -FilePath $logFilePath -Append
            if($_vmBootFailedCount -gt 0) {
                "Failed to get boot time for $_vmBootFailedCount VMs" | Tee-Object -FilePath $logFilePath -Append
                "----------------------------------------------------------" | Tee-Object -FilePath $logFilePath -Append
            }

            # Add vm average boot results to the Azure storage table
            if($storageTable -ne $null) {
                try {
                    # Average vm boot time
                    Add-TableEntity -Table $storageTable -PartitionKey $_executionId -RowKey "AverageBootTime" -Value $_vmBootTimeAvg
                    $vmResultIndex += 1

                    # Absolute vm boot time
                    Add-TableEntity -Table $storageTable -PartitionKey $_executionId -RowKey "AbsoluteBootTime" -Value $_vmBootTimeAbsolute
                    $vmResultIndex += 1

                    # Max vm boot time
                    Add-TableEntity -Table $storageTable -PartitionKey $_executionId -RowKey "MaxBootTime" -Value $_vmBootTimeMax
                    $vmResultIndex += 1

                    # Max vm boot time
                    Add-TableEntity -Table $storageTable -PartitionKey $_executionId -RowKey "MinBootTime" -Value $_vmBootTimeMin
                    $vmResultIndex += 1

                    # Summary
                    Add-TableEntity -Table $storageTable -PartitionKey $_executionId -RowKey "Summary" -Value "$_vmBootTimeCount A1 VMs in $_vmBootTimeAbsolute sec @ $_vmBootTimeAvg sec/VM"
                    $vmResultIndex += 1

                } catch {
                    "Adding Azure storage table summary entry for row $vmResultIndex failed." | Tee-Object -FilePath $logFilePath -Append
                }
            } else {
                "Azure storage table object $storageTable is null" | Tee-Object -FilePath $logFilePath -Append
            }

            "----------------------------------------------------------" | Tee-Object -FilePath $vmbootResultFile -Append
            "$_vmBootTimeCount Azure A1-sized VMs cold booted in $_vmBootTimeAbsolute seconds at an average start time $_vmBootTimeAvg seconds/VM" | Tee-Object -FilePath $vmbootResultFile -Append
            "----------------------------------------------------------" | Tee-Object -FilePath $vmbootResultFile -Append
            "Minimum vm boot time is $_vmBootTimeMin sec and maximum vm boot time is $_vmBootTimeMax sec" | Tee-Object -FilePath $vmbootResultFile -Append
            "----------------------------------------------------------" | Tee-Object -FilePath $vmbootResultFile -Append
            "$_vmBootTimeCount A1 VMs in $_vmBootTimeAbsolute sec @ $_vmBootTimeAvg sec/VM" | Tee-Object -FilePath $vmbootResultFile -Append
            "----------------------------------------------------------" | Tee-Object -FilePath $vmbootResultFile -Append
            if($_vmBootFailedCount -gt 0) {
                "Failed to get boot time for $_vmBootFailedCount VMs" | Tee-Object -FilePath $vmbootResultFile -Append
                "----------------------------------------------------------" | Tee-Object -FilePath $vmbootResultFile -Append
            }
        }
        else {
            Write-Error "Failed to get VM boot results" -ForegroundColor Red
            "Failed to get VM boot results" | Tee-Object -FilePath $logFilePath -Append
            "Failed to get VM boot results" | Tee-Object -FilePath $vmbootResultFile -Append
        }

        "VM boot storm test finished." | Tee-Object -FilePath $logFilePath -Append
        "VM boot storm test finished." | Tee-Object -FilePath $statusFilePath -Append

        # Upload VM boot results and logs file to Azure storage container
        $storageContainerName = "results-vmbootstorm"
        if($storageContext -ne $null) {
            try {
                New-AzureStorageContainer -Name $storageContainerName -Permission Blob -Context $storageContext -Verbose -ErrorAction Stop;
                try {
                    Set-AzureStorageBlobContent -File $vmbootResultFile -Container $storageContainerName -Context $storageContext -ErrorAction Stop;
                    Set-AzureStorageBlobContent -File $logFilePath -Container $storageContainerName -Context $storageContext -ErrorAction Stop;
                }
                catch {
                    "Failed to upload VM boot storm result and log file." | Tee-Object -FilePath $logFilePath -Append
                }
            } catch {
                "Failed to create storage container $storageContainerName to upload result and log file." | Tee-Object -FilePath $logFilePath -Append
            }
        }
        else {
            "Cannot upload VM boot storm result and log file as storage context is null." | Tee-Object -FilePath $logFilePath -Append
        }
    }
    catch
    {
        "Unexpected error in bootstorm" | Tee-Object -FilePath $logFilePath -Append
        "$_" | Tee-Object -FilePath $logFilePath -Append
        "$($_.ScriptStackTrace)" | Tee-Object -FilePath $logFilePath -Append
    }
    finally
    {
        "Bootstorm complete" | Tee-Object -FilePath $logFilePath -Append
        Stop-Transcript
    }
}

function IsAzureStack
{
    param
    (
        [Parameter(Mandatory)]
        $Location
    )
    if($Location -eq "AzureCloud" -or $Location -eq "AzureChinaCloud" -or $Location -eq "AzureUSGovernment"  -or $Location -eq "AzureGermanCloud") {
        return $false
    }
    return $true

}

VMBootAll
