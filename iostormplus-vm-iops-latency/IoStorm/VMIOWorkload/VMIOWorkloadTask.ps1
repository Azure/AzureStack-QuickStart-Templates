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
# MIIjewYJKoZIhvcNAQcCoIIjbDCCI2gCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAzTJ1SkqMDSHpK
# U99y44gy3aXVRS3ZmLOefdWH8ywzraCCDXYwggX0MIID3KADAgECAhMzAAAB3vl+
# gOdHKPWkAAAAAAHeMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjAxMjE1MjEzMTQ0WhcNMjExMjAyMjEzMTQ0WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQC42o7GuqPBrC9Z9N+JtpXANgk2m77zmZSuuBKQmr5pZRmQCht/u/V21N5nwBWK
# NGwCZNdI98dyYGYORRZgrMOh8JWxDBjLMQYtqklGLw5ZPw3OCGCIM2ZU0snDlvZ3
# nKwys5NtPlY4shJxcVM2dhMnXhRTqvtexmeWpfmvtiop7jJn2Sdq0iDybDyU2vMz
# nH2ASetgjvuW2eP4d6zQXlboTBBu1ZxTv/aCRrWCWUPge8lHr3wtiPJHMyxmRHXT
# ulS2VksZ6iI9RLOdlqup9UOcnKRaj1usJKjwADu75+fegAZ4HPWSEXXmpBmuhvbT
# Euwa04eiL7ZKbG3mY9EqpiJ7AgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUbrkwVx/G26M/PsNzHEotPDOdBMcw
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzQ2MzAwODAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAHBTJKafCqTZswwxIpvl
# yU+K/+9oxjswaMqV+yGkRLa7LDqf917yb+IHjsPphMwe0ncDkpnNtKazW2doVHh3
# wMNXUYX6DzyVg1Xr/MTYaai0/GkPR/RN4MSBfoVBDzXJSisnYEWlK1TbI1J1mNTU
# iyiaktveVsH3xQyOVXQEpKFW17xYoHGjYm8s5v22mRE/ShVgsEW9ckxeQbJPCkPc
# PiqD4eXwPguTxv06Pwxva8lsjsPDvo2EgwozBCNGRAxsv2pEl0bh+yOtaFpfQWG7
# yMskiLQwWWoWFyuzm6yiKmZ/jdfO98xR1bFUhQMdwQoMi0lCUMx6YQJj1WpNUTDq
# X0ttJGny2aPWsoOgZ5fzKHNfCowOA+7hLc6gCVRBzyMN/xvV19aKymPt8I/J5gqA
# ZCQT19YgNKyhHUYS4GnFyMr/0GCezE8kexDGeQ3JX1TpHQvcz/dghK30fWM9z44l
# BjNcMV/HtTuefSFsr9tCp53wVaw65LudxSjH+/a2zUa85KKCBzj/GU4OhDaa5Wd4
# 8jr0JSm/515Ynzm1Xje5Ai/qo9xaGCrjrVcJUxBXd/SZPorm3HN6U1aJnL2Kw6nY
# 8Rs205CIWT28aFTecMQ6+KnMt1NZR4pogBnnpWSLc92JMbUd1Z6IbauU6U/oOjyl
# WOtkYUKbyE7EvK9GwUQXMds/MIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCFVswghVXAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAHe+X6A50co9aQAAAAAAd4wDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEILdb/towSM5psszaT/OTK2k6
# 9w+PmP+qI5kw++zvpDbjMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAma6Wh/svwiEaNeWDuVo8fFfy1SiGrOgkUaN6ucYywwLe1tlS6CSdnHxa
# be5uln3XOs3b3mAcC5GfKQ5UeBlqmw209f4XXwuk8oK0Babg2dYkPwGZzOpZd9bR
# UMLGHqodpNGbm1OYskS5knJ27iomuVYygIgiIAmLm8bkjvwwcZ0BhBXi3ypcr5YH
# qIXmjgDVKoYSx5dZ/ge0bkLaDw04HBonvoD80HYvwzaEbInxgszP7w+BNbKGPZja
# j0puzA3yEUcLPORpswTBWhpBYMZUqTeTJaFUCAgbqh0M48k0LV+hnH2UOjItZv2Z
# 7+OXlvm/Vx0N1Ek6q2Jd/lKAHAVUxqGCEuUwghLhBgorBgEEAYI3AwMBMYIS0TCC
# Es0GCSqGSIb3DQEHAqCCEr4wghK6AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFRBgsq
# hkiG9w0BCRABBKCCAUAEggE8MIIBOAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCAjKAqcrhnY1FfFmtrnrXfUt4bfcfrevF9/JNLV3LfjjwIGYUObsGZP
# GBMyMDIxMDkyNjA3MDE0MC43NTFaMASAAgH0oIHQpIHNMIHKMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjoyMjY0LUUz
# M0UtNzgwQzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCC
# DjwwggTxMIID2aADAgECAhMzAAABSqT3McT/IqJJAAAAAAFKMA0GCSqGSIb3DQEB
# CwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNV
# BAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTIwMTExMjE4MjU1
# OFoXDTIyMDIxMTE4MjU1OFowgcoxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMx
# JjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOjIyNjQtRTMzRS03ODBDMSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEF
# AAOCAQ8AMIIBCgKCAQEA3sooZmSiWCy9URo0oxNVlmASXyiGwuAdHiBQVYtm9bMt
# t6AOhEi2l8V372ZpbaE8WWBP7C/uXF/o4HgcVhmAd8ilxmEZTr95uzKZdgCYArMq
# mHvWnElTkXbbxhNJMtyhIAhQ0FlV1MQhkgsQ9PmAjvtiy7tgoy59KaJk/OpiWQRf
# b90eE5yij3TOAglFMbW7aQXvDprsPnTIcoTjp4YTCrCMTEREII20UENCtN9ggP8h
# yPTMqKRiOIlFpo82Oe8FpEn94WQbPyAPZfJheOWw2MMY9oY9BO39GbeevFzJcbII
# giFZ0ExcxMuXsEwMop4sFDR3qkV9LUtEmj6loooGJQIDAQABo4IBGzCCARcwHQYD
# VR0OBBYEFHGMYRgx+sCGNYqT/31+uCYqqT/hMB8GA1UdIwQYMBaAFNVjOlyKMZDz
# Q3t8RhvFM2hahW1VMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9z
# b2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1RpbVN0YVBDQV8yMDEwLTA3LTAx
# LmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljVGltU3RhUENBXzIwMTAtMDctMDEuY3J0
# MAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZIhvcNAQEL
# BQADggEBAFELrt1GOAUVL2S/vZV97yBD4eDcWlfZNjI6rieu0+r0PfpR3J2vaJtn
# LmfsumFe9bbRsNO6BQeLC7J9aebJzagR6+j5Ks0LPFdyPn1a/2VCkGC0vo4znrH6
# /XNs3On+agzCTdS/KwTlp/muS18W0/HpqmpyNTUgO3T2FfzRkDOo9+U8/ILkKPcn
# wNCKVDPb9PNJm9xuAIz2+7Au72n1tmEl6Y0/77cuseR3Jx8dl/eO/tAECKAS/JVv
# aaueWiYUgoLIlbVw6sGMirKe1C3k8rzMrFf/JmXKJFuvxzQNDDy1ild7KiuChV63
# 2wAX63eD9xjNWiBbirCG7JmYSZOVNIowggZxMIIEWaADAgECAgphCYEqAAAAAAAC
# MA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAxMDAeFw0xMDA3MDEyMTM2NTVaFw0yNTA3MDEyMTQ2NTVaMHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
# MIIBCgKCAQEAqR0NvHcRijog7PwTl/X6f2mUa3RUENWlCgCChfvtfGhLLF/Fw+Vh
# wna3PmYrW/AVUycEMR9BGxqVHc4JE458YTBZsTBED/FgiIRUQwzXTbg4CLNC3ZOs
# 1nMwVyaCo0UN0Or1R4HNvyRgMlhgRvJYR4YyhB50YWeRX4FUsc+TTJLBxKZd0WET
# bijGGvmGgLvfYfxGwScdJGcSchohiq9LZIlQYrFd/XcfPfBXday9ikJNQFHRD5wG
# Pmd/9WbAA5ZEfu/QS/1u5ZrKsajyeioKMfDaTgaRtogINeh4HLDpmc085y9Euqf0
# 3GS9pAHBIAmTeM38vMDJRF1eFpwBBU8iTQIDAQABo4IB5jCCAeIwEAYJKwYBBAGC
# NxUBBAMCAQAwHQYDVR0OBBYEFNVjOlyKMZDzQ3t8RhvFM2hahW1VMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/
# MB8GA1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJ
# oEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01p
# Y1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYB
# BQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9v
# Q2VyQXV0XzIwMTAtMDYtMjMuY3J0MIGgBgNVHSABAf8EgZUwgZIwgY8GCSsGAQQB
# gjcuAzCBgTA9BggrBgEFBQcCARYxaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL1BL
# SS9kb2NzL0NQUy9kZWZhdWx0Lmh0bTBABggrBgEFBQcCAjA0HjIgHQBMAGUAZwBh
# AGwAXwBQAG8AbABpAGMAeQBfAFMAdABhAHQAZQBtAGUAbgB0AC4gHTANBgkqhkiG
# 9w0BAQsFAAOCAgEAB+aIUQ3ixuCYP4FxAz2do6Ehb7Prpsz1Mb7PBeKp/vpXbRkw
# s8LFZslq3/Xn8Hi9x6ieJeP5vO1rVFcIK1GCRBL7uVOMzPRgEop2zEBAQZvcXBf/
# XPleFzWYJFZLdO9CEMivv3/Gf/I3fVo/HPKZeUqRUgCvOA8X9S95gWXZqbVr5MfO
# 9sp6AG9LMEQkIjzP7QOllo9ZKby2/QThcJ8ySif9Va8v/rbljjO7Yl+a21dA6fHO
# mWaQjP9qYn/dxUoLkSbiOewZSnFjnXshbcOco6I8+n99lmqQeKZt0uGc+R38ONiU
# 9MalCpaGpL2eGq4EQoO4tYCbIjggtSXlZOz39L9+Y1klD3ouOVd2onGqBooPiRa6
# YacRy5rYDkeagMXQzafQ732D8OE7cQnfXXSYIghh2rBQHm+98eEA3+cxB6STOvdl
# R3jo+KhIq/fecn5ha293qYHLpwmsObvsxsvYgrRyzR30uIUBHoD7G4kqVDmyW9rI
# DVWZeodzOwjmmC3qjeAzLhIp9cAvVCch98isTtoouLGp25ayp0Kiyc8ZQU3ghvkq
# mqMRZjDTu3QyS99je/WZii8bxyGvWbWu3EQ8l1Bx16HSxVXjad5XwdHeMMD9zOZN
# +w2/XU/pnR4ZOC+8z1gFLu8NoFA12u8JJxzVs341Hgi62jbb01+P3nSISRKhggLO
# MIICNwIBATCB+KGB0KSBzTCByjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEm
# MCQGA1UECxMdVGhhbGVzIFRTUyBFU046MjI2NC1FMzNFLTc4MEMxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVALwE
# 7oaFIMrBM3cpBNW0QeKIemuYoIGDMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# UENBIDIwMTAwDQYJKoZIhvcNAQEFBQACBQDk+feLMCIYDzIwMjEwOTI2MDMzMTIz
# WhgPMjAyMTA5MjcwMzMxMjNaMHcwPQYKKwYBBAGEWQoEATEvMC0wCgIFAOT594sC
# AQAwCgIBAAICDwECAf8wBwIBAAICEVQwCgIFAOT7SQsCAQAwNgYKKwYBBAGEWQoE
# AjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkq
# hkiG9w0BAQUFAAOBgQB4RmVDm6Pi+EuOPyT2vHJfEH09izcMK3IUUr/EtkC+M+9k
# i4usR45vs22EA37GXfJUf5ewfQlh/KfIvLl+62YVPcHmZwZlPzHZ4TR22P+AguDj
# z4Be0kiCnXo3cB3R90iStQmFFXFTGrr1hCr2Q1kQHUjSOibSzUS89ppfJsVYsjGC
# Aw0wggMJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# SqT3McT/IqJJAAAAAAFKMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMx
# DQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIDrz3VXFmjTLKeBLwQorxY4D
# onH6KEKf3UC27wfZJMXbMIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgbB2S
# 162521f+Sftir8BViIFZkGr6fgQVVDzNQPciUQMwgZgwgYCkfjB8MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAUqk9zHE/yKiSQAAAAABSjAiBCCO0jOx
# BjcTj2Bj+BZBRZYqZeEL1alkHUnGaI1+a/fvhTANBgkqhkiG9w0BAQsFAASCAQBp
# XK1GJvXoTq2eRf9pQAja3tmip8Z+6INY1BdlINnIQhg4q8BZH23HEtEo+A058DMN
# /hTL/O9ip1hgXBmTxpDn/SInIoHiX8W79i8ogiKgjnQbjBOy+jyWOKhhZio8RV0y
# kIjaRXHAUZFufS+Cq0jiWxcb7dbrROc/wHdbbgq7efHXTi6TXiWhc6zcIrTJDZur
# tJJHoFtVi161/irOtp1XBeO9y4H73nMVAS71O4TE0XgBeOmr2HcpJG15rpm795hv
# C4mQkPpBlcN3Oox8ikKUSFhFnyfgCnGz37o9FJW/iBUwAVuWXzm4Xmmgwn9D0xIc
# syU0cBM4g0qcjSo4Z4sa
# SIG # End signature block
