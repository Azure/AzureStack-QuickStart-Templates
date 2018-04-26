#
# Copyright="?Microsoft Corporation. All rights reserved."
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
    [int32]$VMIoBlockSize,
    [Parameter(Mandatory)]
    [int32]$VMIoDuration,
    [Parameter(Mandatory)]
    [int32]$VMIoReadPercentage,
    [Parameter(Mandatory)]
    [int32]$VMIoMaxLatency,
    [int32]$FixedIops = 0,
    [string]$RunFixedIoLatencyTestAfterGoalSeek = "false",
    [int32]$DataDisks = 1
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
function VMIOWorkload {
    # Turn off private firewall off

    # RunFixedIoLatencyTestAfterGoalSeek is passed as a parameter from 
    # a scheduled task. It must be a string or int.
    if($RunFixedIoLatencyTestAfterGoalSeek -eq "true") {
        [bool]$RunFixedIoLatencyTestAfterGoalSeek = $true
    } else {
        [bool]$RunFixedIoLatencyTestAfterGoalSeek = $false
    }
    $ioStormMode = Get-IoStormMode -RunFixedIoLatencyTestAfterGoalSeek $RunFixedIoLatencyTestAfterGoalSeek -FixedIops $FixedIops

    netsh advfirewall set privateprofile state off
    netsh advfirewall set publicprofile state off

    # Local file storage location
    $localPath = "$env:SystemDrive"

    # Log file
    $logFileName = "VMWorkload-$VMName.log"
    $logFilePath = "$localPath\$logFileName"
    $restartRun = $false
	if(Test-Path $logFilePath -ErrorAction SilentlyContinue) {
        if($ioStormMode -eq "FixedIops") {
            "Restarting fixed IOPS run" | Out-File $logFilePath -Encoding ASCII -Append
            $restartRun = $true
        } else {
		    Write-Host "Log file already exists. Skipping test execution."
		    "Log file already exists. Skipping test execution." | Out-File $logFilePath -Encoding ASCII -Append
		    return
        }
	}

    # Result SMB share
    $smbshare = "\\$ControllerVMPrivateIP\smbshare"

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

    $timeoutInSeconds = 7200
    # Setup connection to smb share of a controller VM, if net use fails retry until timeout
    $dtTime = Get-Date
    "Waiting for a share $smbshare to get online by a controller VM at $dtTime" | Out-File $logFilePath -Encoding ASCII -Append
    $startTime = Get-Date
    $elapsedTime = $(Get-Date) - $startTime
    $syncTimeoutInSeconds = $timeoutInSeconds
    while($elapsedTime.TotalSeconds -lt $syncTimeoutInSeconds) {
        net use $smbshare /user:$VMAdminUserName $VMAdminPassword
        if((Test-Path $smbshare) -eq $false) {
            Start-Sleep 3
        }
        else {
            $dtTime = Get-Date
            Write-Verbose "SMB share $smbshare is accessible"
            "Share $smbshare is made online by a controller VM at $dtTime" | Out-File $logFilePath -Encoding ASCII -Append
            break
        }
        $elapsedTime = $(Get-Date) - $startTime
    }

    # Wait for smb share on a controller VM
    $dtTime = Get-Date
    "Waiting for controller VM to get ready $controllerReadySignalFile at $dtTime" | Out-File $logFilePath -Encoding ASCII -Append
    if((Test-Path $smbshare) -eq $true) {
        ##########################################
        ### WAIT TO START IO WORKLOAD PRE-SYNC ###
        ##########################################
        # Wait for all VMs to boot and come up before timeout
        $noOfRetries = $timeoutInSeconds/10
        while($noOfRetries -gt 0) {
            if((Test-Path $controllerReadySignalFile) -eq $true) {
                Write-Verbose "Wait to start pre-io synchronization is over"
                $noOfRetries = 0
            }
            Start-Sleep -Seconds 10
            if($noOfRetries -gt 0) {
                Write-Verbose "Waiting to start pre-io synchronization... $noOfRetries"
                $noOfRetries--
            }
        }
    }

    # Create pre-sync file
    $dtTime = Get-Date
    "Creating pre-sync file at $dtTime" | Out-File $logFilePath -Encoding ASCII -Append
    "$VMName" | Out-File $localPath\$ioPreSyncFileName -Encoding ASCII -Append

    # Setup connection to smb share of a controller VM, if net use fails retry until timeout
    $startTime = Get-Date
    $elapsedTime = $(Get-Date) - $startTime
    # Wait until timeout
    $syncTimeoutInSeconds = $timeoutInSeconds/3
    while($elapsedTime.TotalSeconds -lt $syncTimeoutInSeconds) {
        net use $smbshare /user:$VMAdminUserName $VMAdminPassword
        if((Test-Path $smbshare) -eq $false) {
            Start-Sleep 3
        }
        else {
            "SMB share $smbshare is accessible" | Out-File $logFilePath -Encoding ASCII -Append
            break
        }
        $elapsedTime = $(Get-Date) - $startTime
    }

    if((Test-Path $smbshare) -eq $true) {
        #############################
        ### DOWNLOAD DISKSPD TOOL ###
        #############################
        $diskspdSource = "https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/master/iostorm-vm-iops-latency/diskspd.exe"
        $diskspdFileName = [System.IO.Path]::GetFileName($diskspdSource)
        $diskspdDestination = "$localPath\$diskspdFileName"
        $workloadFileDrive = "F:"
        $workloadFilePath = $workloadFileDrive + "\iobw.tst"

        if($restartRun -eq $false) {
            
            $webClient = New-Object System.Net.WebClient
            $_date = Get-Date -Format hh:mmtt
            "Downloading diskspd IO load generating tool from $diskspdSource to $diskspdDestination at $_date" | Out-File $logFilePath -Encoding ASCII -Append
            $success = $false
            $downloadRetries = 20
            while($success -eq $false -and $downloadRetries -gt 0 ) {
                $success = $true
                $webClient.DownloadFile($diskspdSource, $diskspdDestination)
                $_date = Get-Date -Format hh:mmtt
                if((Test-Path $diskspdDestination) -eq $true) {
                    "Downloading diskspd IO load generating tool succeeded at $_date" | Out-File $logFilePath -Encoding ASCII -Append
                }
                else {
                    "WARN: Downloading diskspd IO load generating tool failed at $_date Retrying." | Out-File $logFilePath -Encoding ASCII -Append
                    $success = $false
                    $downloadRetries--
                    Start-Sleep -Seconds 30
                }
            }
            if($success -eq $false) {
                "ERROR: Downloading diskspd IO load generating tool failed at $_date No more retries, failing test." | Out-File $logFilePath -Encoding ASCII -Append
                return
            }
            # Create target file
            #unsure why we tried defaulting to this. Test would fail rather than no use the specified disk below
            #$workloadFileDrive = $env:SYSTEMDRIVE
        
            # Initialize disk
            InitializeAllDisks -NumDisks $DataDisks
            $testFileList = BuildFileList -NumDisks $DataDisks -FileName "iobw.tst"
            "Test file list: $testFileList" | Out-File $logFilePath -Encoding ASCII -Append
                        
            $diskspdCmd = "$diskspdDestination -t1 -b512K -w100 -d300 -W0 -C0 -o4 -Sh -n -c4G $testFileList"
		    "Starting diskspd workload $diskspdCmd" | Out-File $logFilePath -Encoding ASCII -Append
            cmd /c $diskspdCmd | Out-Null

            $diskspdCmd = "$diskspdDestination -t1 -16k -w0 -d300 -W0 -C0 -o4 -Sh -n $testFileList"
            "Starting diskspd workload $diskspdCmd" | Out-File $logFilePath -Encoding ASCII -Append
            cmd /c $diskspdCmd | Out-Null
        }

        # QD and Thread values
        $qd = -1
        $threads = -1
        $iteration = 0
        try {
            if($restartRun -eq $true) {
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
                $iteration = $measure.Maximum 
            }
        } catch {
            "Failed to determine start iteration. Defaulting to 0. $_" | Out-File $logFilePath -Encoding ASCII -Append
        }
        "Starting with iteration $iteration" | Out-File $logFilePath -Encoding ASCII -Append
        # Stop IO workload execution when either no QD and THREADS value is provided by a controller VM or IO workload pre-synchronization fail
        $continueIoWorkloadExecution = $true

        ##########################################
        ### IO WORKLOAD PRE-SYNC + IO WORKLOAD ###
        ##########################################
        # Copy pre-sync file
		"Coyping pre-sync file $ioPreSyncFileName to $ioPreSyncShare" | Out-File $logFilePath -Encoding ASCII -Append
        Copy-Item $localPath\$ioPreSyncFileName $ioPreSyncShare\

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
                $fixedIopsPerDisk = 0

                # Check IO workload sync file
                if((Test-Path $ioWorkloadStartSignalFileIteration) -eq $true) {
                    $ioWorkloadSyncDidSucceed = $true
                    Write-Verbose "Start io-workload iteration $iteration synchronization succeeded."
                    "Start io-workload iteration $iteration synchronization succeeded (Sync signal $ioWorkloadStartSignalFileIteration is present)" | Out-File $logFilePath -Encoding ASCII -Append

                    # Get QD and THREADS values from a controller VM
                    $lines = Get-Content $ioWorkloadStartSignalFileIteration
                    foreach($line in $lines) {
                        if($line.Contains("QD") -eq $true) {
                            $qd = $line.Split(':')[1]
                        }
                        if($line.Contains("THREADS") -eq $true) {
                             $threads = $line.Split(':')[1]
                        }
                        if($line.Contains("FIXED") -eq $true) {
                            [int32]$fixedIopsPerDisk = [convert]::ToInt32($line.Split(':')[1], 10)
                        }
                    }
                    $noOfRetries = 0
                    # If Controller VM haven't provided QD or Thread value, stop IO workload execution
                    if(($qd -lt 0) -or ($threads -lt 0)) {
                        $continueIoWorkloadExecution = $false
                    }
                    break
                }

                # Wait for IO workload sync signal
                if(($noOfRetries -gt 0) -and ($ioWorkloadSyncDidSucceed -eq $false) -and $continueIoWorkloadExecution) {
                    Write-Verbose "Start io-workload iteration $iteration waiting... $noOfRetries"
                    if(($noOfRetries%6) -eq 0) {
                        "Start io-workload iteration $iteration waiting... $noOfRetries" | Out-File $logFilePath -Encoding ASCII -Append
                    }
                    $noOfRetries--
                    Start-Sleep -Seconds 10
                }
            }
            # Workload synchronization failed
            if($ioWorkloadSyncDidSucceed -eq $false) {
                $continueIoWorkloadExecution = $false
                Write-Verbose "Start io-workload iteration $iteration failed. IO workload execution is stopped."
                "Start io-workload iteration $iteration failed. IO workload execution is stopped." | Out-File $logFilePath -Encoding ASCII -Append
            }
            ###################
            ### IO WORKLOAD ###
            ###################
            elseif($continueIoWorkloadExecution) {
                # Io result share directory for current iteration
                $ioResultIterationShare = $ioResultShare + "\iteration-$iteration"

                # Validate parameters
                $VMIoWritePercentage = 100 - $VMIoReadPercentage
                if(($VMIoReadPercentage + $VMIoWritePercentage) -ne 100) {
                    Write-Verbose "IO Read Percentage $VMIoReadPercentage and IO Write Percentage $VMIoWritePercentage values are not valid. Both values must add upto 100."
                    "IO Read Percentage $VMIoReadPercentage and IO Write Percentage $VMIoWritePercentage values are not valid. Both values must add upto 100." | Out-File $logFilePath -Encoding ASCII -Append

                    # Update read/write % to valid default values
                    $VMIoReadPercentage = 70
                    $VMIoWritePercentage = 100 - $VMIoReadPercentage
                    Write-Verbose "Proceeding with IO Read Percentage $VMIoReadPercentage and IO Write Percentage $VMIoWritePercentage values"
                    "Proceeding with IO Read Percentage $VMIoReadPercentage and IO Write Percentage $VMIoWritePercentage values" | Out-File $logFilePath -Encoding ASCII -Append
                }

                # Run IO workload
                "Starting IO load generation with QD: $qd and THREADS: $threads" | Out-File $logFilePath -Encoding ASCII -Append

                # Refer to http://aka.ms/diskspd : 
                # t - threads, b - block size, w - write ratio, r - random, d - duration, W - warmup period, C - cooldown period, o - queue depth, Sh - disable software and hardware write caching, n - disable affinity, L - measure latency, D - capture IOPS higher-order stats in intervals of ms
                if($fixedIopsPerDisk -eq 0 -or $FixedIops -eq 0) {
                    $diskspdCmd = "$diskspdDestination -t$threads -b$VMIoBlockSize -w$VMIoWritePercentage -r -d$VMIoDuration -W45 -C45 -o$qd -Sh -n -L -D -z -Rxml $testFileList > $localPath\$ioResultFileName"
                } elseif($fixedIopsPerDisk -ne 0 -and $RunFixedIoLatencyTestAfterGoalSeek -eq $true) {
                    $bytesPerMs = ($VMIoBlockSize * $fixedIopsPerDisk) / 1000 / ($threads * $DataDisks)
                    if($bytesPerMs -lt 1) {
                        $bytesPerMs = 1
                    }
                    "Using fixed IO -g$bytesPerMs" | Out-File $logFilePath -Encoding ASCII -Append
                    $diskspdCmd = "$diskspdDestination -t$threads -g$bytesPerMs -b$VMIoBlockSize -w$VMIoWritePercentage -r -d120 -W45 -C45 -o$qd -Sh -n -L -D -z -Rxml $testFileList > $localPath\$ioResultFileName"
                } else {
                    $bytesPerMs = ($VMIoBlockSize * $FixedIops) / 1000 / ($threads * $DataDisks)
                    if($bytesPerMs -lt 1) {
                        $bytesPerMs = 1
                    }
                    "Using fixed IO -g$bytesPerMs" | Out-File $logFilePath -Encoding ASCII -Append
                    $diskspdCmd = "$diskspdDestination -t$threads -g$bytesPerMs -b$VMIoBlockSize -w$VMIoWritePercentage -r -d$VMIoDuration -W45 -C45 -o$qd -Sh -n -L -D -z -Rxml $testFileList > $localPath\$ioResultFileName"
                }
                cmd /c $diskspdCmd
                "IO workload has finished" | Out-File $logFilePath -Encoding ASCII -Append

                # Update Machine Name to add right VM index as all VMs uses same name (e.g. VMBootVM => VMBootVM0, VMBootVM1, VMBootVM2...)
                (Get-Content $localPath\$ioResultFileName) | Foreach-Object {$_ -replace "<ComputerName>$env:COMPUTERNAME</ComputerName>", "<ComputerName>$VMName</ComputerName>"} | Set-Content $localPath\$ioResultFileName

                # Copy result file
                Copy-LogFiles -Src $localPath\$ioResultFileName -Dest $ioResultIterationShare\ -LogFilePath $logFilePath               
            }
            else {
                Write-Verbose "Stopping IO workload at iteration $iteration"
                "Stopping IO workload at iteration $iteration" | Out-File $logFilePath -Encoding ASCII -Append
            }
            $iteration += 1
        }

        # Copy log file
        Copy-LogFiles -Src $logFilePath -Dest $logShare\ -LogFilePath $logFilePath

    }
    else {
        $dtTime = Get-Date
        Write-Verbose "SMB Share $smbshare is not accessible at $dtTime"
        "SMB share $smbshare is not accessible at $dtTime" | Out-File $logFilePath -Encoding ASCII -Append
        "Cannot run IO test as SMB Share $smbshare is not accessible at $dtTime" | Out-File $localPath\$ioResultFileName -Encoding ASCII -Append
    }
    "Script execution ended" | Out-File $logFilePath -Encoding ASCII -Append
}

function WaitForDisk
{
    param(
    [UInt32]$DiskNumber,
    [UInt64]$RetryIntervalSec = 10,
    [UInt32]$RetryCount = 60
    )
    $diskFound = $false
    Write-Verbose -Message "Checking for disk '$($DiskNumber)' ..."

    for ($count = 0; $count -lt $RetryCount; $count++)
    {
        $disk = Get-Disk -Number $DiskNumber -ErrorAction SilentlyContinue
        if (!!$disk)
        {
            Write-Verbose -Message "Found disk '$($disk.FriendlyName)'."
            $diskFound = $true
            break
        }
        else
        {
            Write-Verbose -Message "Disk '$($DiskNumber)' NOT found."
            Write-Verbose -Message "Retrying in $RetryIntervalSec seconds ..."
            Start-Sleep -Seconds $RetryIntervalSec
        }
    }

    if (!$diskFound)
    {
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
    
    if($disk -eq $null){
        return $false
    }

    if ($disk.PartitionStyle -ne "RAW") {
        "Disk number '$($DiskNumber)' has already been initialized." | Out-File $logFilePath -Encoding ASCII -Append                    
        return $true
    }

    if ($disk.IsOffline -eq $true)
    {
        "Setting disk Online" | Out-File $logFilePath -Encoding ASCII -Append                    
        $disk | Set-Disk -IsOffline $false
    }
    
    if ($disk.IsReadOnly -eq $true)
    {
        "Setting disk to not ReadOnly" | Out-File $logFilePath -Encoding ASCII -Append                    
        $disk | Set-Disk -IsReadOnly $false
    }
    
    if ($disk.PartitionStyle -eq "RAW")
    {
        "Initializing disk number $($DiskNumber)..." | Out-File $logFilePath -Encoding ASCII -Append                    

        $disk | Initialize-Disk -PartitionStyle GPT -PassThru
        if ($DriveLetter)
        {
            $partition = $disk | New-Partition -DriveLetter $DriveLetter -UseMaximumSize
        }
        else
        {
            $partition = $disk | New-Partition -AssignDriveLetter -UseMaximumSize
        }

        # Sometimes the disk will still be read-only after the call to New-Partition returns.
        Start-Sleep -Seconds 5

        if($partition -ne $null) {
            $volume = $partition | Format-Volume -FileSystem NTFS -Confirm:$false

            "Successfully initialized disk number '$($DiskNumber)'." | Out-File $logFilePath -Encoding ASCII -Append                    
        }
        else {
            "Failed to initialize disk num '$($DiskNumber)'." | Out-File $logFilePath -Encoding ASCII -Append                    
        }
    }
    
    if (($disk | Get-Partition | Where-Object { $_.DriveLetter -ne "`0" } | Select-Object -ExpandProperty DriveLetter) -ne $DriveLetter)
    {
        "Changing drive letter to $DriveLetter" | Out-File $logFilePath -Encoding ASCII -Append                    
        Set-Partition -DiskNumber $disknumber -PartitionNumber (Get-Partition -Disk $disk | Where-Object { $_.DriveLetter -ne "`0" } | Select-Object -ExpandProperty PartitionNumber) -NewDriveLetter $driveletter
    }

    return true
}

function Copy-LogFiles
{
    param(
    [String] $Src,
    [String] $Dest,
    [string] $LogFilePath
    )
    $success = $false
    $iteration = 0
    while(!$success) {        
        try {
            Copy-Item $Src $Dest -Force
            $success = $true
        } catch {
            $success = $false
            $d = Get-Date
            "$d Failed to copy logs for $iteration. Src: $Src Dest: $Dest Retrying. $_" | Out-File $LogFilePath -Encoding ASCII -Append
            $iteration++
            Start-Sleep -Seconds 10
        }
    }
}
function InitializeAllDisks
{
    param(
    [int32]$NumDisks
    )
    $driveLetters = "FGHIJKLMNOPQRSTUVWXYZ".ToCharArray()
    for($i = 0; $i -lt $NumDisks; $i++) {        
        $diskNumber = $i + 2
        if(WaitForDisk -DiskNumber $diskNumber) {
        [string]$driveLetter = $driveLetters[$i]
            if(InitializeDisk -DiskNumber $diskNumber -DriveLetter $driveLetter) {
				"Initializing disk $diskNumber at $($driveLetters[$i])" | Out-File $logFilePath -Encoding ASCII -Append                    
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

function Get-IoStormMode {
    param (
        [bool]$RunFixedIoLatencyTestAfterGoalSeek,
        [int32]$FixedIops
    )
    if($RunFixedIoLatencyTestAfterGoalSeek -eq $true -and $FixedIops -ne 0) {
        $ioStormInitialMode = "GoalSeek"
        $ioStormMode = "GoalSeekFixedIops"
    } elseif($RunFixedIoLatencyTestAfterGoalSeek -eq $false -and $FixedIops -ne 0) {
        $ioStormMode = "FixedIops"
    } else {
        $ioStormMode = "GoalSeek"
    }
    return $ioStormMode
}

VMIOWorkload
