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
                        
            $diskspdCmd = "$diskspdDestination -t2 -b512K -w70 -d1800 -W0 -C0 -o8 -Sh -n -r -c$($fileSizeGB)G $testFileList"
            Log-Info -Message "Starting diskspd workload $diskspdCmd"
            cmd /c $diskspdCmd | Out-Null
        } else {
            if ($StripeDisk) {
                $DataDisks = 1
            }
            
            $testFileList = BuildFileList -NumDisks $DataDisks -FileName "iobw.tst"
            $diskspdCmd = "$diskspdDestination -t2 -b512K -w70 -d1800 -W0 -C0 -o8 -Sh -n -r $testFileList"
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

    $poolName = "TestDiskPool"
    $vdName = "TestVD"
    $volName = "TestVolume"
    $storage = Get-StorageSubSystem
    New-StoragePool -FriendlyName $poolName -PhysicalDisks $physicalDisk -StorageSubSystemName $storage.Name
    New-VirtualDisk -FriendlyName $vdName `
                    -ResiliencySettingName Simple `
                    -NumberOfColumns $physicalDisk.Count `
                    -UseMaximumSize -Interleave 65536 -StoragePoolFriendlyName $poolName
    $vdiskNumber = (Get-Disk -FriendlyName $vdName).Number
    Initialize-Disk -FriendlyName $vdName -PartitionStyle GPT -PassThru
    New-Partition -UseMaximumSize -DiskNumber $vdiskNumber -DriveLetter $DriveLetter
    Format-Volume -DriveLetter $DriveLetter -FileSystem NTFS -NewFileSystemLabel $volName -AllocationUnitSize 65536 -Force -Confirm:$false

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

            ++$diskNumber
            if (InitializeDiskPool -DiskPoolSize $NumDisks -DriveLetter $driveLetter) {
                Log-Info -Message "Initializing disk $diskNumber at $driveLetter with a pool of $NumDisks disks"
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

# SIG # Begin signature block
# MIIjnwYJKoZIhvcNAQcCoIIjkDCCI4wCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCA90aRC8S4TRgU
# QFb/f/y3BFuDLR2xdHdC7ZPAxh5b1aCCDYEwggX/MIID56ADAgECAhMzAAAB32vw
# LpKnSrTQAAAAAAHfMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjAxMjE1MjEzMTQ1WhcNMjExMjAyMjEzMTQ1WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQC2uxlZEACjqfHkuFyoCwfL25ofI9DZWKt4wEj3JBQ48GPt1UsDv834CcoUUPMn
# s/6CtPoaQ4Thy/kbOOg/zJAnrJeiMQqRe2Lsdb/NSI2gXXX9lad1/yPUDOXo4GNw
# PjXq1JZi+HZV91bUr6ZjzePj1g+bepsqd/HC1XScj0fT3aAxLRykJSzExEBmU9eS
# yuOwUuq+CriudQtWGMdJU650v/KmzfM46Y6lo/MCnnpvz3zEL7PMdUdwqj/nYhGG
# 3UVILxX7tAdMbz7LN+6WOIpT1A41rwaoOVnv+8Ua94HwhjZmu1S73yeV7RZZNxoh
# EegJi9YYssXa7UZUUkCCA+KnAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUOPbML8IdkNGtCfMmVPtvI6VZ8+Mw
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDYzMDA5MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAnnqH
# tDyYUFaVAkvAK0eqq6nhoL95SZQu3RnpZ7tdQ89QR3++7A+4hrr7V4xxmkB5BObS
# 0YK+MALE02atjwWgPdpYQ68WdLGroJZHkbZdgERG+7tETFl3aKF4KpoSaGOskZXp
# TPnCaMo2PXoAMVMGpsQEQswimZq3IQ3nRQfBlJ0PoMMcN/+Pks8ZTL1BoPYsJpok
# t6cql59q6CypZYIwgyJ892HpttybHKg1ZtQLUlSXccRMlugPgEcNZJagPEgPYni4
# b11snjRAgf0dyQ0zI9aLXqTxWUU5pCIFiPT0b2wsxzRqCtyGqpkGM8P9GazO8eao
# mVItCYBcJSByBx/pS0cSYwBBHAZxJODUqxSXoSGDvmTfqUJXntnWkL4okok1FiCD
# Z4jpyXOQunb6egIXvkgQ7jb2uO26Ow0m8RwleDvhOMrnHsupiOPbozKroSa6paFt
# VSh89abUSooR8QdZciemmoFhcWkEwFg4spzvYNP4nIs193261WyTaRMZoceGun7G
# CT2Rl653uUj+F+g94c63AhzSq4khdL4HlFIP2ePv29smfUnHtGq6yYFDLnT0q/Y+
# Di3jwloF8EWkkHRtSuXlFUbTmwr/lDDgbpZiKhLS7CBTDj32I0L5i532+uHczw82
# oZDmYmYmIUSMbZOgS65h797rj5JJ6OkeEUJoAVwwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIVdDCCFXACAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAd9r8C6Sp0q00AAAAAAB3zAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgE+bYYHmO
# 8fA5ZzwmHS0Pvj0R6Ga4FWnyVW57jkUFCI4wQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQAZdxDmKKQF34I5ARBSytboMjMCoPq3nhrbc1WpFaT1
# Eo89zN3go1vwm/hPTd+HoJy24B4CazvBMQzTL6s4M6UwGeBXLfYBbkAw0AnHOypi
# Ufq2hUUa9V657JhdYr8giKVfe/7Lo4c4lvxm7rDpm7zPzp2uDQc9H2UCifSkB0AJ
# A98em3oiGkzBjZCCAyZCJi4Fry4p6vqai3KpNYZZ68m8+Ir6THO5gLIzMakZrBVC
# siebZkazM2X+lzLpvUcPriYjf20p2C/2bYZ7EIUUffjbHL+MWL/1qM6q/vmnF8Ce
# QuILv7XGjTeZNmXRba10NavGlCbePPvrsQlCPyUULqFLoYIS/jCCEvoGCisGAQQB
# gjcDAwExghLqMIIS5gYJKoZIhvcNAQcCoIIS1zCCEtMCAQMxDzANBglghkgBZQME
# AgEFADCCAVkGCyqGSIb3DQEJEAEEoIIBSASCAUQwggFAAgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEINN5065KZrVHcOgRab6tBDX8TONE/YK/lx1AwSFp
# O59oAgZhSLgnZxMYEzIwMjEwOTIyMDcxOTA1LjE5NFowBIACAfSggdikgdUwgdIx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEmMCQGA1UECxMdVGhh
# bGVzIFRTUyBFU046MDg0Mi00QkU2LUMyOUExJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2Wggg5NMIIE+TCCA+GgAwIBAgITMwAAATnM6OhDi/A0
# 4QAAAAABOTANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0Eg
# MjAxMDAeFw0yMDEwMTUxNzI4MjFaFw0yMjAxMTIxNzI4MjFaMIHSMQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQg
# SXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1Mg
# RVNOOjA4NDItNEJFNi1DMjlBMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2hP5jOMl
# kyWhjrMqBvyiePhaH5g3T39Qwdu6HqAnWcLlz9/ZKoC/QFz45gb0ad14IvqFaFm2
# J6o+vhhbf4oQJOHDTcjZXBKQTbQT/w6LCWvdCXnFQl2a8nEd42EmE7rxRVmKumbH
# oEKV+QwYdGc70q5O8M2YkqJ/StcrFhFtmhFxcvVZ+gg4azzvE87+soIzYV6zqM2K
# WO/TSy9Zeoi5X4QobV6AKuwJH08ySZ2lQBXznd8rwDzy6+BYqJXim+b+V+7E3741
# b6cQ9fmONApHLhkGqo07/B14NkGqqO978hAjXtVoQpKjKu6yxXzsspQnj0rlfsV/
# HySW/l+izx7KTwIDAQABo4IBGzCCARcwHQYDVR0OBBYEFJmem4ZyVMKZ2pKKsZ9G
# 9lAtBgzpMB8GA1UdIwQYMBaAFNVjOlyKMZDzQ3t8RhvFM2hahW1VMFYGA1UdHwRP
# ME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1
# Y3RzL01pY1RpbVN0YVBDQV8yMDEwLTA3LTAxLmNybDBaBggrBgEFBQcBAQROMEww
# SgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMv
# TWljVGltU3RhUENBXzIwMTAtMDctMDEuY3J0MAwGA1UdEwEB/wQCMAAwEwYDVR0l
# BAwwCgYIKwYBBQUHAwgwDQYJKoZIhvcNAQELBQADggEBAFhcKGrz/zcahc3BWu1D
# goi/EA2xJvu69hGIk6FtIPHXWMiuVmtRQHf8pyQ9asnP2ccfRz/dMqlyk/q8+INc
# CLEElpSgm91xuCFYbFhAhLJtoozf38aH5rY2ZxWN9buDEknJfiGiK6Q+8kkCNWmb
# Wj2DxRwEF8IfBwjF7EPhYDgdilKz486uwhgosor1GuDWilYjGoMNq3lrwDIkY/83
# KUpJhorlpiBdkINEsVkCfzyELme9C3tamZtMSXxrUZwX6Wrf3dSYEAqy36PJZJri
# wTwhvzjIeqD8eKzUUh3ufE2/EjEAbabBhCo2+tUoynT6TAJtjdiva4g7P73/VQrS
# cMcwggZxMIIEWaADAgECAgphCYEqAAAAAAACMA0GCSqGSIb3DQEBCwUAMIGIMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNy
# b3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0xMDA3MDEy
# MTM2NTVaFw0yNTA3MDEyMTQ2NTVaMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAy
# MDEwMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqR0NvHcRijog7PwT
# l/X6f2mUa3RUENWlCgCChfvtfGhLLF/Fw+Vhwna3PmYrW/AVUycEMR9BGxqVHc4J
# E458YTBZsTBED/FgiIRUQwzXTbg4CLNC3ZOs1nMwVyaCo0UN0Or1R4HNvyRgMlhg
# RvJYR4YyhB50YWeRX4FUsc+TTJLBxKZd0WETbijGGvmGgLvfYfxGwScdJGcSchoh
# iq9LZIlQYrFd/XcfPfBXday9ikJNQFHRD5wGPmd/9WbAA5ZEfu/QS/1u5ZrKsajy
# eioKMfDaTgaRtogINeh4HLDpmc085y9Euqf03GS9pAHBIAmTeM38vMDJRF1eFpwB
# BU8iTQIDAQABo4IB5jCCAeIwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFNVj
# OlyKMZDzQ3t8RhvFM2hahW1VMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsG
# A1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNX2VsuP6KJc
# YmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9z
# b2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIz
# LmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3J0
# MIGgBgNVHSABAf8EgZUwgZIwgY8GCSsGAQQBgjcuAzCBgTA9BggrBgEFBQcCARYx
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL1BLSS9kb2NzL0NQUy9kZWZhdWx0Lmh0
# bTBABggrBgEFBQcCAjA0HjIgHQBMAGUAZwBhAGwAXwBQAG8AbABpAGMAeQBfAFMA
# dABhAHQAZQBtAGUAbgB0AC4gHTANBgkqhkiG9w0BAQsFAAOCAgEAB+aIUQ3ixuCY
# P4FxAz2do6Ehb7Prpsz1Mb7PBeKp/vpXbRkws8LFZslq3/Xn8Hi9x6ieJeP5vO1r
# VFcIK1GCRBL7uVOMzPRgEop2zEBAQZvcXBf/XPleFzWYJFZLdO9CEMivv3/Gf/I3
# fVo/HPKZeUqRUgCvOA8X9S95gWXZqbVr5MfO9sp6AG9LMEQkIjzP7QOllo9ZKby2
# /QThcJ8ySif9Va8v/rbljjO7Yl+a21dA6fHOmWaQjP9qYn/dxUoLkSbiOewZSnFj
# nXshbcOco6I8+n99lmqQeKZt0uGc+R38ONiU9MalCpaGpL2eGq4EQoO4tYCbIjgg
# tSXlZOz39L9+Y1klD3ouOVd2onGqBooPiRa6YacRy5rYDkeagMXQzafQ732D8OE7
# cQnfXXSYIghh2rBQHm+98eEA3+cxB6STOvdlR3jo+KhIq/fecn5ha293qYHLpwms
# ObvsxsvYgrRyzR30uIUBHoD7G4kqVDmyW9rIDVWZeodzOwjmmC3qjeAzLhIp9cAv
# VCch98isTtoouLGp25ayp0Kiyc8ZQU3ghvkqmqMRZjDTu3QyS99je/WZii8bxyGv
# WbWu3EQ8l1Bx16HSxVXjad5XwdHeMMD9zOZN+w2/XU/pnR4ZOC+8z1gFLu8NoFA1
# 2u8JJxzVs341Hgi62jbb01+P3nSISRKhggLXMIICQAIBATCCAQChgdikgdUwgdIx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1p
# Y3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEmMCQGA1UECxMdVGhh
# bGVzIFRTUyBFU046MDg0Mi00QkU2LUMyOUExJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVAA1NlP4b3paEjXQ/He5K
# BMazZYwHoIGDMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJ
# KoZIhvcNAQEFBQACBQDk9TDYMCIYDzIwMjEwOTIyMTIzNDMyWhgPMjAyMTA5MjMx
# MjM0MzJaMHcwPQYKKwYBBAGEWQoEATEvMC0wCgIFAOT1MNgCAQAwCgIBAAICInYC
# Af8wBwIBAAICETwwCgIFAOT2glgCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYB
# BAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQUFAAOB
# gQCkvZ9NIuSa22WKDI5qPG9sbAIB4varKgJLW1WgHuQyBj5eaxPdLeixqdLEFX4r
# Lxb38xbGA0RIPj2WFBLhjAiuo9iv6c6OLVOvQ+kArwZYkjVgkeHi1z+bgT4hT2w3
# E2fSnyggfXht6ednuD5MwLObclY/MSe3lFuvRR2Dwryt2DGCAw0wggMJAgEBMIGT
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAABOczo6EOL8DThAAAA
# AAE5MA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQ
# AQQwLwYJKoZIhvcNAQkEMSIEIPO9fPMeQyDJttyHjIT9Bb7zyJ3CVSqoUOtfDoZK
# 5yK0MIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgPKGO5Dij1yR7MUKx4oEF
# rnxqVSfzmnqfJqbUoAcP/J8wgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0EgMjAxMAITMwAAATnM6OhDi/A04QAAAAABOTAiBCDhEiC6+QP6Ez8hiQs0Q/uA
# Nrag6D0tD+bVRyghHP8GVzANBgkqhkiG9w0BAQsFAASCAQBY1H5bgyTTy/YAr7Cq
# zef58bcitrC9Pj8RJoXpwsA3G92f5nb8KwAA2BX8OR7oxXtFuNLY0In1HLKDWi/+
# yoxP6VClb42fNUsQQHiCJXnTCxzjyBtQsHWm2Xpbnypehsi5ga0OGeDMt4ow64A5
# W77FR+e0GTpzgSDPUqFTh1sgMuj7gB5PbTEDsA9ZB1phZxfmDoqkWF0BKWma9YHd
# 8A+mRY9PxXTP32aEe/jqA6DuDEPK3IIZuYnQWKKpuzpQ91563pMVQCxbSKddCDBO
# S/6MHci2wsFSutIkkAP63ZcrYRutEV3FesOiKbcEFgxCJaSg8Bvvl8qKRIMZcHtq
# GtHE
# SIG # End signature block
