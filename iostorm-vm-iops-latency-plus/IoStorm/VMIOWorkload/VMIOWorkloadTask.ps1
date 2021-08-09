#
# Copyright="Microsoft Corporation. All rights reserved."
#

param (
    [Parameter(Mandatory)]
    [string]$ControllerVMName,
    [Parameter(Mandatory)]
    [string]$ControllerVMPrivateIP,
    [Parameter(Mandatory)]
    [string]$VMName,
    [Parameter(Mandatory)]
    [string]$VMAdminUserName,
    [Parameter(Mandatory)]
    [string]$VMAdminPassword,
    [Parameter(Mandatory)]
    [int]$DataDisks,
    [Parameter(Mandatory)]
    [int]$DataDiskSizeGB,
    [bool]$StripeDisk = $true
)

# 1. Waits for a '$controllerReadySignalFile' (e.g. \\10.0.0.6\smbshare\iopresyncstart.txt) from a Controller VM then starts IO pre-sync 
# 2. Creates pre-sync file '$ioPreSyncFileName' (e.g. IOPreSync-VM0.log) to indicate VM is up and waiting to start a workload
# 3. Waits for a '$ioWorkloadStartSignalFile' file (e.g. \\10.0.0.6\smbshare\ioworkloadstart-0) from a Controller VM (which indicates all VMs are ready and have created IOPreSync-VMx.log files) to signal all VMs to start IO workload with given 'QD' and 'THREAD' values inside the file
# 4. Copy IO result file '$ioResultFileName' (e.g. IOResult-VM0.log) in IO result directory '$ioResultShare' on a Controller VM (e.g. \\10.0.0.6\smbshare\ioresult\ioresult-0)
# 5. If IO workload latency values is < given maxLatency, repeat step #3 with new values of 'QD' and 'THREAD', repeat step #4 and step #5
# 6. All execution logs are written to a file  '$logFileName' (e.g. VMWorkload-VM0.log) and then copied to '$logShare' on a Controller VM (e.g. \\10.0.0.6\smbshare\logs\)

# Waits for a '$ioPreWorkloadSyncSucceedSignalFile' file (e.g. \\10.0.0.6\smbshare\iopresyncsucceed.txt) (which indicates all VMs are ready and have created IOPreSync-VMx.log files) from a Controller VM then starts IO workload
# Copy IO result file '$ioResultFileName' (e.g. IOResult-VM0.log) in IO result directory '$ioResultShare' on a Controller VM (e.g. \\10.0.0.6\smbshare\ioresult\)
# All execution logs are written to a file  '$logFileName' (e.g. VMWorkload-VM0.log) and then copied to '$logShare' on a Controller VM (e.g. \\10.0.0.6\smbshare\logs\)

# Log file
$logFileName = "VMWorkload-$VMName.log"
$logFilePath = "$env:SystemDrive\$logFileName"

# Result SMB share
$smbshare = "\\$ControllerVMPrivateIP\smbshare"
# Log directory
$logShare = "$smbshare\logs"

function VMIOWorkload {
    # Turn off private firewall off
    netsh advfirewall set privateprofile state off
    netsh advfirewall set publicprofile state off

    # Local file storage location
    $localPath = "$env:SystemDrive"

    $restartRun = $false
    if (Test-Path $logFilePath -ErrorAction SilentlyContinue) {
        Log-Info -Message "Restarting fixed IOPS run"
        $restartRun = $true
    }

    Start-Transcript -Path $logFilePath -Append -Force -ErrorAction SilentlyContinue
    # Create IO workload pre-sync directory
    $ioPreSyncShare = "$smbshare\iopresync"
    $ioPreSyncFileName = "IOPreSync-$VMName.log"

    # Sync signal to start IO pre-sync from controller vm
    $controllerReadySignalFile = "$smbshare\iopresyncstart.txt"

    # Start IO workload signal file from controller VM (also indicates pre IO workload sync succeed singal)
    $ioWorkloadStartSignalFile = "$smbshare\ioworkloadstart-"
    #$ioPreWorkloadSyncSucceedSignalFile = "$smbshare\iopresyncsucceed.txt"

    # Log directory
    $logShare = "$smbshare\logs"

    # Create IO result directory
    $ioResultShare = "$smbshare\ioresult"
    $ioResultFileName = "IOResult-$VMName.xml"

    $timeoutInSeconds = 14400
    # Setup connection to smb share of a controller VM, if net use fails retry until timeout
    $dtTime = Get-Date
    Log-Info -Message "Waiting for a share $smbshare to get online by a controller VM at $dtTime"
    $startTime = Get-Date
    $elapsedTime = $(Get-Date) - $startTime
    $syncTimeoutInSeconds = $timeoutInSeconds
    while($elapsedTime.TotalSeconds -lt $syncTimeoutInSeconds) {
        net use $smbshare /user:$VMAdminUserName $VMAdminPassword
        if ((Test-Path $smbshare) -eq $false) {
            Start-Sleep -Seconds 5
            Log-Info -Message "SMB share $smbshare is not accessible."
        }
        else {
            $dtTime = Get-Date
            Log-Info -Message "SMB share $smbshare is accessible."
            Log-Info -Message "Share $smbshare is made online by a controller VM at $dtTime"
            break
        }

        $elapsedTime = $(Get-Date) - $startTime
    }

    Start-Sleep -Seconds 30
    if ((Test-Path $smbshare) -eq $false) {
        return
    }

    Copy-Item -Path $logFilePath -Destination $logShare\ -Force -ErrorAction SilentlyContinue

    $dtTime = Get-Date
    Log-Info -Message "Waiting for controller VM to get ready $controllerReadySignalFile at $dtTime"
    if ((Test-Path $smbshare) -eq $true) {
        ##########################################
        ### WAIT TO START IO WORKLOAD PRE-SYNC ###
        ##########################################
        # Wait for all VMs to boot and come up before timeout
        $noOfRetries = $timeoutInSeconds/10
        while($noOfRetries -gt 0) {
            if ((Test-Path $controllerReadySignalFile) -eq $true) {
                Log-Info -Message "Wait to start pre-io synchronization is over"
                $noOfRetries = 0
            }

            Start-Sleep -Seconds 10
            if ($noOfRetries -gt 0) {
                Log-Info -Message "Waiting to start pre-io synchronization... $noOfRetries"
                $noOfRetries--
            }
        }
    }

    # Create pre-sync file
    $dtTime = Get-Date
    Log-Info -Message "Creating pre-sync file at $dtTime"
    "$VMName" | Out-File $localPath\$ioPreSyncFileName -Encoding ASCII -Append

    if ((Test-Path $smbshare) -eq $true) {
        $diskspdFileName = "diskspd.exe"
        $diskspdDestination = "$localPath\$diskspdFileName"

        if (-not (Test-Path $diskspdDestination)) {
            Log-Warning "Unable to access DiskSpd $diskspdDestination."
            return
        }

        if ($restartRun -eq $false) {
            # Create target file
            #unsure why we tried defaulting to this. Test would fail rather than no use the specified disk below
            #$workloadFileDrive = $env:SYSTEMDRIVE
        
            # Initialize disk
            InitializeAllDisks -NumDisks $DataDisks -StripeDisk $StripeDisk

            $diskUsage = 0.8

            if ($StripeDisk) {
                $fileSizeGB = [int]($DataDiskSizeGB * $DataDisks * $diskUsage)
                $DataDisks = 1
            }
            else {
                $fileSizeGB = [int]($DataDiskSizeGB * $diskUsage)
            }

            $fileSizeGB = [math]::Max($fileSizeGB, 1)

            $testFileList = BuildFileList -NumDisks $DataDisks -FileName "iobw.tst"
            Log-Info -Message "Test file list: $testFileList"
                        
            $diskspdCmd = "$diskspdDestination -t2 -b512K -w90 -d1200 -W0 -C0 -o8 -Sh -n -r -c$($fileSizeGB)G $testFileList"
            Log-Info -Message "Starting diskspd workload $diskspdCmd"
            cmd /c $diskspdCmd | Out-Null
        } else {
            if ($StripeDisk) {
                $DataDisks = 1
            }
            
            $testFileList = BuildFileList -NumDisks $DataDisks -FileName "iobw.tst"
            $diskspdCmd = "$diskspdDestination -t2 -b512K -w90 -d1200 -W0 -C0 -o8 -Sh -n -r $testFileList"
            Log-Info -Message "Starting diskspd workload $diskspdCmd"
            cmd /c $diskspdCmd | Out-Null
        }

        # QD and Thread values
        $qd = -1
        $threads = -1
        $iteration = 0
        try {
            if ($restartRun -eq $true) {
                #find highest iteration
                $startFilePath = "$ioWorkloadStartSignalFile*"
                $startFiles = Get-ChildItem $startFilePath
                $startNames = $startFiles.Name
                $allIterations = @()
                foreach($n in $startNames) {
                    $splitStr = $n.Split("-")
                    $iterStr = $splitStr[1]
                    $iterNum = [convert]::ToInt32($iterStr, 10)
                    $allIterations += $iterNum
                }

                $measure = $allIterations | Measure-Object -Maximum
                $iteration = $measure.Maximum + 1
            }
        } catch {
            Log-Info -Message "Failed to determine start iteration. Defaulting to 0. $_"
        }

        Log-Info -Message "Starting with iteration $iteration"
        # Stop IO workload execution when either no QD and THREADS value is provided by a controller VM or IO workload pre-synchronization fail
        $continueIoWorkloadExecution = $true

        ##########################################
        ### IO WORKLOAD PRE-SYNC + IO WORKLOAD ###
        ##########################################
        $vmIoWritePercentage = 40
        $vmIoBlockSize = 4096
        $vmIoDuration = 600
        $vmIoRandomPercentage = 50
        $vmIoRandomDistribution = $null

        # Copy pre-sync file
        Log-Info -Message "Coyping pre-sync file $ioPreSyncFileName to $ioPreSyncShare"
        Copy-Item $localPath\$ioPreSyncFileName $ioPreSyncShare\ -Verbose

        while($continueIoWorkloadExecution) {                       
            ############################
            ### IO WORKLOAD PRE-SYNC ###
            ############################
            $ioWorkloadStartSignalFileIteration = "$ioWorkloadStartSignalFile$iteration"
            # Flag to indicate sync succeed
            $ioWorkloadSyncDidSucceed = $false
            # Wait for timeout
            $noOfRetries = $timeoutInSeconds/10
            while(($noOfRetries -gt 0) -and ($ioWorkloadSyncDidSucceed -eq $false)) {
                $fixedIops = 0

                # Check IO workload sync file
                if ((Test-Path $ioWorkloadStartSignalFileIteration) -eq $true) {
                    $ioWorkloadSyncDidSucceed = $true
                    Log-Info -Message "Start io-workload iteration $iteration synchronization succeeded (Sync signal $ioWorkloadStartSignalFileIteration is present)"

                    # Get QD and THREADS values from a controller VM
                    $lines = Get-Content $ioWorkloadStartSignalFileIteration
                    foreach($line in $lines) {
                        if ($line.Contains("QD") -eq $true) {
                            $qd = $line.Split('#')[1]
                        }
                        if ($line.Contains("THREADS") -eq $true) {
                             $threads = $line.Split('#')[1]
                        }
                        if ($line.Contains("FIXED") -eq $true) {
                            [int32]$fixedIops = [convert]::ToInt32($line.Split('#')[1], 10)
                        }
                        if ($line.Contains("WRITEPCT") -eq $true) {
                            [int32]$vmIoWritePercentage = [convert]::ToInt32($line.Split('#')[1], 10)
                        }
                        if ($line.Contains("BLOCK") -eq $true) {
                            [int32]$vmIoBlockSize = [convert]::ToInt32($line.Split('#')[1], 10)
                        }
                        if ($line.Contains("DURATION") -eq $true) {
                            [int32]$vmIoDuration = [convert]::ToInt32($line.Split('#')[1], 10)
                        }
                        if ($line.Contains("RANDOMPCT") -eq $true) {
                            [int32]$vmIoRandomPercentage = [convert]::ToInt32($line.Split('#')[1], 10)
                        }
                        if ($line.Contains("RDPCT") -eq $true) {
                            [string]$vmIoRandomDistribution = $line.Split('#')[1]
                        }
                    }

                    $randomCtrl = ""
                    if ($vmIoRandomPercentage -gt 0) {
                        $randomCtrl = "-rs$vmIoRandomPercentage"
                        if ($vmIoRandomDistribution) {
                            $randomCtrl += " -rdpct$vmIoRandomDistribution"
                        }
                    } else {
                        $randomCtrl = "-si"
                    }

                    Log-Info -Message "Using $randomCtrl for DiskSpd to control random IO."

                    $noOfRetries = 0
                    # If Controller VM haven't provided QD or Thread value, stop IO workload execution
                    if (($qd -lt 0) -or ($threads -lt 0)) {
                        $continueIoWorkloadExecution = $false
                    }

                    break
                }

                # Wait for IO workload sync signal
                if (($noOfRetries -gt 0) -and ($ioWorkloadSyncDidSucceed -eq $false) -and $continueIoWorkloadExecution) {
                    Log-Info -Message "Start io-workload iteration $iteration waiting... $noOfRetries"
                    $noOfRetries--
                    Start-Sleep -Seconds 10
                }
            }

            # Workload synchronization failed
            if ($ioWorkloadSyncDidSucceed -eq $false) {
                $continueIoWorkloadExecution = $false
                Log-Info -Message "Start io-workload iteration $iteration failed. IO workload execution is stopped."
            }
            ###################
            ### IO WORKLOAD ###
            ###################
            elseif ($continueIoWorkloadExecution) {
                # Io result share directory for current iteration
                $ioResultIterationShare = $ioResultShare + "\iteration-$iteration"

                # Validate parameters
                $vmIoReadPercentage = 100 - $vmIoWritePercentage
                Log-Info -Message "Proceeding with IO Read Percentage $vmIoReadPercentage and IO Write Percentage $vmIoWritePercentage values"

                # Run IO workload
                Log-Info -Message "Starting IO load generation with QD: $qd and THREADS: $threads"

                # Refer to http://aka.ms/diskspd : 
                # t - threads, b - block size, w - write ratio, r - random, d - duration, W - warmup period, C - cooldown period, o - queue depth, Sh - disable software and hardware write caching, n - disable affinity, L - measure latency, D - capture IOPS higher-order stats in intervals of ms                
                if ($fixedIops -ne 0) {
                    $fixedIopsPerThreads = [math]::Ceiling($fixedIops / $threads)

                    Log-Info -Message "Using fixed IO -g$($fixedIopsPerThreads)i"
                    $diskspdCmd = "$diskspdDestination -t$threads -g$($fixedIopsPerThreads)i -b$vmIoBlockSize -w$vmIoWritePercentage $randomCtrl -d$vmIoDuration -W60 -C60 -o$qd -Sh -n -L -D -z -Rxml $testFileList > $localPath\$ioResultFileName"
                } else {
                    $diskspdCmd = "$diskspdDestination -t$threads -b$vmIoBlockSize -w$vmIoWritePercentage $randomCtrl -d$vmIoDuration -W60 -C60 -o$qd -Sh -n -L -D -z -Rxml $testFileList > $localPath\$ioResultFileName"
                }
                
                Log-Info -Message "Starting IO workload: $diskspdCmd"
                cmd /c $diskspdCmd
                Log-Info -Message "IO workload has finished: $diskspdCmd"

                # Update Machine Name to add right VM index as all VMs uses same name (e.g. VMBootVM => VMBootVM0, VMBootVM1, VMBootVM2...)
                (Get-Content $localPath\$ioResultFileName) | Foreach-Object {$_ -replace "<ComputerName>$env:COMPUTERNAME</ComputerName>", "<ComputerName>$VMName</ComputerName>"} | Set-Content $localPath\$ioResultFileName

                # Copy result file
                Copy-LogFiles -Src $localPath\$ioResultFileName -Dest $ioResultIterationShare\           
            }
            else {
                Log-Info -Message "Stopping IO workload at iteration $iteration"
            }

            $iteration += 1
        }

        # Copy log file
        Copy-LogFiles -Src $logFilePath -Dest $logShare\
    }
    else {
        $dtTime = Get-Date
        Log-Info -Message "SMB Share $smbshare is not accessible at $dtTime"
        "Cannot run IO test as SMB Share $smbshare is not accessible at $dtTime" | Out-File $localPath\$ioResultFileName -Encoding ASCII -Append
    }
    
    Log-Info -Message "Script execution ended"

    Stop-Transcript -ErrorAction SilentlyContinue
}

function WaitForDisk
{
    param(
        [UInt32]$DiskNumber,
        [UInt64]$RetryIntervalSec = 10,
        [UInt32]$RetryCount = 60
    )

    $diskFound = $false
    Log-Info -Message "Checking for disk '$($DiskNumber)' ..."

    for ($count = 0; $count -lt $RetryCount; $count++) {
        $disk = Get-Disk -Number $DiskNumber -ErrorAction SilentlyContinue
        if (!!$disk) {
            Log-Info -Message "Found disk '$($disk.FriendlyName)'."
            $diskFound = $true
            break
        } else {
            Log-Info -Message "Disk '$($DiskNumber)' NOT found."
            Log-Info -Message "Retrying in $RetryIntervalSec seconds ..."
            Start-Sleep -Seconds $RetryIntervalSec
        }
    }

    if (!$diskFound) {
        throw "Disk '$($DiskNumber)' NOT found after $RetryCount attempts."
    }

    return $diskFound
}

function InitializeDisk
{
    param(
        [UInt32] $DiskNumber,
        [String] $DriveLetter
    )
    
    $disk = Get-Disk -Number $DiskNumber
    
    if ($disk -eq $null) {
        return $false
    }

    if ($disk.PartitionStyle -ne "RAW") {
        Log-Info -Message "Disk number '$($DiskNumber)' has already been initialized."
        return $true
    }

    if ($disk.IsOffline -eq $true) {
        Log-Info -Message "Setting disk Online"
        $disk | Set-Disk -IsOffline $false
    }
    
    if ($disk.IsReadOnly -eq $true) {
        Log-Info -Message "Setting disk to not ReadOnly"
        $disk | Set-Disk -IsReadOnly $false
    }
    
    if ($disk.PartitionStyle -eq "RAW") {
        Log-Info -Message "Initializing disk number $($DiskNumber)..."

        $disk | Initialize-Disk -PartitionStyle GPT -PassThru
        if ($DriveLetter) {
            $partition = $disk | New-Partition -DriveLetter $DriveLetter -UseMaximumSize
        }
        else {
            $partition = $disk | New-Partition -AssignDriveLetter -UseMaximumSize
        }

        # Sometimes the disk will still be read-only after the call to New-Partition returns.
        Start-Sleep -Seconds 5

        if ($partition -ne $null) {
            $volume = $partition | Format-Volume -FileSystem NTFS -Confirm:$false

            Log-Info -Message "Successfully initialized disk number '$($DiskNumber)'."
        }
        else {
            Log-Info -Message "Failed to initialize disk num '$($DiskNumber)'."
        }
    }
    
    if (($disk | Get-Partition | Where-Object { $_.DriveLetter -ne "`0" } | Select-Object -ExpandProperty DriveLetter) -ne $DriveLetter) {
        Log-Info -Message "Changing drive letter to $DriveLetter"
        Set-Partition -DiskNumber $disknumber -PartitionNumber (Get-Partition -Disk $disk | Where-Object { $_.DriveLetter -ne "`0" } | Select-Object -ExpandProperty PartitionNumber) -NewDriveLetter $driveletter
    }

    return true
}

function InitializeDiskPool
{
    param(
        [UInt32] $DiskPoolSize,
        [String] $DriveLetter
    )

    $physicalDisk = Get-PhysicalDisk | where {$_.CanPool -eq $true}

    if ($physicalDisk.Count -eq 0) {
        return $false
    }

    if ($physicalDisk.Count -ne $DiskPoolSize) {
        throw "Unexpected number of data disk found. Expected value: $DiskPoolSize. Actual value: $($physicalDisk.Count)."
    }

    $diskPool = Get-StorageSubSystem | New-StoragePool -FriendlyName "testDiskPool" -PhysicalDisks $physicalDisk -ResiliencySettingNameDefault Simple
    New-Volume -FriendlyName "TestVolume" -FileSystem NTFS -ProvisioningType "Fixed" -Size $($diskPool.Size * 0.95) -StoragePoolUniqueId $($diskPool.UniqueId) -AccessPath "$($DriveLetter):"
    Format-Volume -DriveLetter $DriveLetter -Force -Confirm:$false

    return $true
}

function Copy-LogFiles
{
    param(
        [String] $Src,
        [String] $Dest
    )

    $success = $false
    $iteration = 0

    while(!$success) {        
        try {
            Copy-Item $Src $Dest -Force
            $success = $true
        } catch {
            if ($iteration -gt 10) {
                break
            }

            $success = $false
            $d = Get-Date
            Log-Info -Message "$d Failed to copy logs for $iteration. Src: $Src Dest: $Dest Retrying. $_"
            $iteration++
            Start-Sleep -Seconds 10
        }
    }
}

function InitializeAllDisks
{
    param(
        [int32]$NumDisks,
        [bool] $StripeDisk
    )

    $driveLetters = "FGHIJKLMNOPQRSTUVWXYZ".ToCharArray()
    $diskNumber = 1

    if ((-not $StripeDisk) -or ($NumDisks -eq 1)) {
        for ($i = 0; $i -lt $NumDisks; $i++) {
            ++$diskNumber

            if (WaitForDisk -DiskNumber $diskNumber) {
                [string]$driveLetter = $driveLetters[$i]

                if (InitializeDisk -DiskNumber $diskNumber -DriveLetter $driveLetter) {
                    Log-Info -Message "Initializing disk $diskNumber at $driveLetter)"
                }
            }
        }
    } else {
        [string]$driveLetter = $driveLetters[0]
        $poolDisk = Get-Disk -Number $($diskNumber + $NumDisks + 1) -ErrorAction SilentlyContinue

        if ($poolDisk) {
            Log-Info -Message "Found pool disk '$($poolDisk.FriendlyName)'."
        } else {
            for($i = 0; $i -lt $NumDisks; $i++) {
                ++$diskNumber
                WaitForDisk -DiskNumber $diskNumber
            }

            if (InitializeDiskPool -DiskPoolSize $NumDisks -DriveLetter $driveLetter) {
                Log-Info -Message "Initializing disk $(++$diskNumber) at $driveLetter with a pool of $NumDisks disks"
            }
        }
    }
}

function BuildFileList
{
    param(
        [int32]$NumDisks,
        [string]$FileName
    )

    $driveLetters = "FGHIJKLMNOPQRSTUVWXYZ".ToCharArray()
    $str = ""
    for($i = 0; $i -lt $NumDisks; $i++) {        
        $str += "$($driveLetters[$i]):\$FileName "
    }

    return $str
}

function Log-Info
{
    param (
        [string]$Message
    )

    $str = "$(Get-Date) $Message"
    Write-Host $str
    if ((Test-Path $logShare) -eq $true) {
        $str | Out-File "$logShare\$logFileName" -Encoding ASCII -Append -Force -ErrorAction Ignore
    }
}

VMIOWorkload
Stop-Transcript -ErrorAction SilentlyContinue
