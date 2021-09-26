#
# Copyright="Microsoft Corporation. All rights reserved."
#

##################
# Helper functions
##################
function Log-Info
{
    param(
        [Parameter(ValueFromPipeline=$true)]
        [String] $Message
    )

    if ($Message) {
       Write-Verbose "$env:COMPUTERNAME-$([DateTime]::Now): $Message" -Verbose
    }
}

function Log-Warning
{
    param(
        [Parameter(ValueFromPipeline=$true)]
        [String] $Message,
        [Parameter(ValueFromPipeline=$false)]
        [switch] $Throw
    )

    if ($Message) {
        Write-Warning "$env:COMPUTERNAME-$([DateTime]::Now): $Message"

        if ($Throw) {
            throw $Message
        }
    }
}

function Login-ARM
{
    param(
        [Parameter(Mandatory = $true)]
        [String]$Endpoint,
        [Parameter(Mandatory = $true)]
        [String]$Environment,
        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential,
        [Parameter(Mandatory = $true)]
        [String]$Subscription,
        [Parameter(Mandatory = $true)]
        [String]$TenantId
    )

    Add-AzureRMEnvironment -Name $Environment -ARMEndpoint $Endpoint | Out-Null
    Login-AzureRMAccount -EnvironmentName $Environment -TenantId $TenantId -Credential $Credential | Out-Null
    Set-AzureRMContext -Subscription $Subscription | Out-Null
}

function Login-AdminARM
{
    param(
        [Parameter(Mandatory = $true)]
        [String]$AdminARMEndpoint,
        [Parameter(Mandatory = $true)]
        [PSCredential]$AdminCredential,
        [Parameter(Mandatory = $true)]
        [String]$TenantId
    )

    # Login Admin
    Log-Info "Login Admin ARM $($AdminARMEndpoint)."
    Login-ARM -Endpoint $AdminARMEndpoint -Environment "AdminARM" -Credential $AdminCredential -Subscription "Default Provider Subscription" -TenantId $TenantId
}

function Setup-IoStormControllerShare
{
    param(
        [Parameter(Mandatory = $true)]
        [String]$ControllerShare,
        [Parameter(Mandatory = $true)]
        [int]$TimeoutInSeconds,
        [Parameter(Mandatory = $true)]
        [String]$VMAdminUserName,
        [Parameter(Mandatory = $true)]
        [String]$VMAdminPassword
    )

    # Setup connection to smb share of a controller VM, if net use fails retry until timeout
    Log-Info -Message "Waiting for a share $ControllerShare to get online by a controller VM."
    $startTime = Get-Date
    $elapsedTime = $(Get-Date) - $startTime
    while($elapsedTime.TotalSeconds -lt $TimeoutInSeconds) {
        try { net use $ControllerShare /user:"testvm\$VMAdminUserName" $VMAdminPassword | Out-Null } catch { Log-Warning "Failed to connect $($ControllerShare): $_"}
        if ((Test-Path $ControllerShare) -eq $false) {
            Log-Info -Message "SMB share $ControllerShare is not accessible."
            Start-Sleep -Seconds 30
        }
        else {
            Log-Info -Message "SMB share $ControllerShare is accessible."
            Log-Info -Message "Share $ControllerShare is made online by controller VM"
            break
        }

        $elapsedTime = $(Get-Date) - $startTime
    }

    return $(Test-Path $ControllerShare)
}

# Function to add a result row to the Azure Storage Table
function Add-TableEntity 
{
    param(
        [Parameter(Mandatory = $true)]
        $Table,
        [Parameter(Mandatory = $true)]
        [String]$PartitionKey,
        [Parameter(Mandatory = $true)]
        [String]$RowKey,
        [Parameter(Mandatory = $false)]
        [String]$Iteration,
        [Parameter(Mandatory = $false)]
        [String]$Details,
        [Parameter(Mandatory = $false)]
        [String]$NumberOfVMs,
        [Parameter(Mandatory = $false)]
        [String]$CpuUtilization,
        [Parameter(Mandatory = $false)]
        [String]$QueueDepth,
        [Parameter(Mandatory = $false)]
        [String]$NumberOfThreads,
        [Parameter(Mandatory = $false)]
        [String]$BlockSize,
        [Parameter(Mandatory = $false)]
        [String]$ReadWriteRatio,
        [Parameter(Mandatory = $false)]
        [int]$RandomIoPercentage,
        [Parameter(Mandatory = $false)]
        [String]$Total_IOPS,
        [Parameter(Mandatory = $false)]
        [String]$Read_IOPS,
        [Parameter(Mandatory = $false)]
        [String]$Write_IOPS,
        [Parameter(Mandatory = $false)]
        [String]$Total_AvgLatency,
        [Parameter(Mandatory = $false)]
        [String]$Read_AvgLatency,
        [Parameter(Mandatory = $false)]
        [String]$Write_AvgLatency,
        [Parameter(Mandatory = $false)]
        [String]$Total_95thPercentile_AvgLatency,
        [Parameter(Mandatory = $false)]
        [String]$Read_95thPercentile_AvgLatency,
        [Parameter(Mandatory = $false)]
        [String]$Write_95thPercentile_AvgLatency,
        [Parameter(Mandatory = $false)]
        [String]$NumberOfDisksPerVM
    )

    if ($Table -eq $null) {
        Log-Warning -Message "Cannot insert entity in null Azure Storage Table"
        return
    }

    $entity = New-Object "Microsoft.WindowsAzure.Storage.Table.DynamicTableEntity, Microsoft.WindowsAzure.Storage, Version=9.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" $PartitionKey, $RowKey
    if ($entity -eq $null) {
        Log-Warning -Message "Cannot insert null entity in Azure Storage Table"
        return
    }

    $entity.Properties.Add("Iteration", $Iteration)
    $entity.Properties.Add("NumberOfThreads", $NumberOfThreads)
    $entity.Properties.Add("QueueDepth", $QueueDepth)
    $entity.Properties.Add("Details", $Details)
    $entity.Properties.Add("NumberofVMs", $NumberOfVMs)
    $entity.Properties.Add("TotalIOPS", $Total_IOPS)
    $entity.Properties.Add("ReadIOPS", $Read_IOPS)
    $entity.Properties.Add("WriteIOPS", $Write_IOPS)
    $entity.Properties.Add("TotalAvgLatency", $Total_AvgLatency)
    $entity.Properties.Add("ReadAvgLatency", $Read_AvgLatency)
    $entity.Properties.Add("WriteAvgLatency", $Write_AvgLatency)
    $entity.Properties.Add("Total95thPercentileAvgLatency", $Total_95thPercentile_AvgLatency)
    $entity.Properties.Add("Read95thPercentileAvgLatency", $Read_95thPercentile_AvgLatency)
    $entity.Properties.Add("Write95thPercentileAvgLatency", $Write_95thPercentile_AvgLatency)
    $entity.Properties.Add("BlockSize", $BlockSize)
    $entity.Properties.Add("ReadWriteRatio", $ReadWriteRatio)
    $entity.Properties.Add("RandomIoPercentage", $RandomIoPercentage)
    $entity.Properties.Add("CpuUtilization", $CpuUtilization)
    $entity.Properties.Add("NumberOfDisksPerVM", $NumberOfDisksPerVM)

    $result = $null
    try {
        $result = $Table.CloudTable.Execute([Microsoft.WindowsAzure.Storage.Table.TableOperation, Microsoft.WindowsAzure.Storage, Version=9.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35]::InsertOrReplace($entity))
    } catch [Exception] {
        Log-Warning -Message "Inserting entity to Azure Storage Table failed with exception $_"

    }

    return $result
}

function New-CSVHeader
{
    param(
        [Parameter(Mandatory = $true)]
        [String]$CsvPath
    )

    $str = "Run,Iteration,Date,NumberOfVMs,QueueDepth,NumberOfThreads,NumberOfDisksPerVM,BlockSize,ReadWriteRatio,RandomIoPercentage,Total_IOPS,Read_IOPS,Write_IOPS,Total_AvgLatency,Read_AvgLatency,Write_AvgLatency,Total_95thPercentile_AvgLatency,Read_95thPercentile_AvgLatency,Write_95thPercentile_AvgLatency"
    $str | Out-File $CsvPath -Width 9999 -Append -Encoding ASCII
}

function Add-CSVRow
{
    param(
        [Parameter(Mandatory = $true)]
        [String]$CsvPath,
        [Parameter(Mandatory = $false)]
        [String]$RunName,
        [Parameter(Mandatory = $false)]
        [String]$Iteration,
        [Parameter(Mandatory = $false)]
        [String]$NumberOfVMs,
        [Parameter(Mandatory = $false)]
        [String]$QueueDepth,
        [Parameter(Mandatory = $false)]
        [String]$NumberOfThreads,
        [Parameter(Mandatory = $false)]
        [String]$BlockSize,
        [Parameter(Mandatory = $false)]
        [String]$ReadWriteRatio,
        [Parameter(Mandatory = $false)]
        [String]$RandomIoPercentage,
        [Parameter(Mandatory = $false)]
        [String]$Total_IOPS,
        [Parameter(Mandatory = $false)]
        [String]$Read_IOPS,
        [Parameter(Mandatory = $false)]
        [String]$Write_IOPS,
        [Parameter(Mandatory = $false)]
        [String]$Total_AvgLatency,
        [Parameter(Mandatory = $false)]
        [String]$Read_AvgLatency,
        [Parameter(Mandatory = $false)]
        [String]$Write_AvgLatency,
        [Parameter(Mandatory = $false)]
        [String]$Total_95thPercentile_AvgLatency,
        [Parameter(Mandatory = $false)]
        [String]$Read_95thPercentile_AvgLatency,
        [Parameter(Mandatory = $false)]
        [String]$Write_95thPercentile_AvgLatency,
        [Parameter(Mandatory = $false)]
        [String]$NumberOfDisksPerVM
    )

    $d = Get-Date
    $str = "$RunName,$Iteration,$d,$NumberOfVMs,$QueueDepth,$NumberOfThreads,$NumberOfDisksPerVM,$BlockSize,$ReadWriteRatio,$RandomIoPercentage,$Total_IOPS,$Read_IOPS,$Write_IOPS,$Total_AvgLatency,$Read_AvgLatency,$Write_AvgLatency,$Total_95thPercentile_AvgLatency,$Read_95thPercentile_AvgLatency,$Write_95thPercentile_AvgLatency"
    $str | Out-File $CsvPath -Width 9999 -Append -Encoding ASCII
}

# Analyze diskspd output xml
## COLUMNS ## VM Name    Write Ratio    Threads    Requests    Block Size    Read IOPS    Read Bytes    Write IOPS    Write Bytes    Avg Read (ms)    Avg Write (ms)    Read (ms) - 25%    Write (ms) - 25%    Read (ms) - 50%    Write (ms) - 50%    Read (ms) - 75%    Write (ms) - 75%    Read (ms) 90%    Write (ms) - 90%    Read (ms) - 95%    Write (ms) - 95%    Read (ms) - 99%    Write (ms) - 99%    Read (ms) - 99.9%    Write (ms) - 99.9%    Read (ms) - 100%    Write (ms) - 100%
function Analyze-DiskspdResultXml {
    param(
        [Parameter(Mandatory = $false)]
        [String]$InputPath = ".",
        [Parameter(Mandatory = $true)]
        [String]$OutPath,
        [Parameter(Mandatory = $true)]
        $StorageTable,
        [Parameter(Mandatory = $true)]
        $ExecutionId,
        [Parameter(Mandatory = $true)]
        $Iteration,
        [Parameter(Mandatory = $true)]
        $RandomIoPercentage
    )

    if ($StorageTable -eq $null) {
        Log-Warning -Message "Storage table is null."
    }

    # Average Read/Write Latency
    $sumAvgReadLatencyForAllXml = 0.0
    $sumAvgWriteLatencyForAllXml = 0.0
    $sumAvgTotalLatencyForAllXml = 0.0
    # 95th Percentile Read/Write Latency
    $sum95thReadLatencyForAllXml = 0.0
    $sum95thWriteLatencyForAllXml = 0.0
    $sum95thTotalLatencyForAllXml = 0.0
    # Average Read/Write IOPS
    $sumAvgReadIopsForAllXml = 0.0
    $sumAvgWriteIopsForAllXml = 0.0
    $totalXml = 0
    # Block Size
    $blockSize = 0
    # Write Ratio
    $writeRatio = 0

    # Header
    if ((Test-Path $OutPath) -eq $false) {
        "VM Name	Avg CPU Usage	Write Ratio	Threads	QueueDepth	Block Size	Read IOPS	Read Bytes	Write IOPS	Write Bytes	Avg Read (ms)	Avg Write (ms)	Read (ms) - 25%	Write (ms) - 25%	Read (ms) - 50%	Write (ms) - 50%	Read (ms) - 75%	Write (ms) - 75%	Read (ms) 90%	Write (ms) - 90%	Read (ms) - 95%	Write (ms) - 95%	Read (ms) - 99%	Write (ms) - 99%	Read (ms) - 99.9%	Write (ms) - 99.9%	Read (ms) - 100%	Write (ms) - 100%" | out-file $OutPath -Encoding ascii -Width 9999 -Append
    }

    $l = @()
    foreach ($i in 25,50,75,90,95,99,99.9,100) { $l += ,[String]$i }

    Get-ChildItem -Path $InputPath -Recurse -Filter *.xml | Sort-Object |% {
        $pwdir = (pwd).Path
        cd $_.Directory.FullName
        $x = [xml](Get-Content $_)

        #$system = $_.Directory.Name + "_" + $x.Results.System.ComputerName
        $vname = $x.Results.System.ComputerName
        $system = $x.Results.System.ComputerName + "_" + $_.Directory.Name
        $t = $x.Results.TimeSpan.TestTimeSeconds

        # Sum of avg read/write latency
        $sumAvgReadLatencyForAllXml += $x.Results.TimeSpan.Latency.AverageReadMilliseconds
        $sumAvgWriteLatencyForAllXml += $x.Results.TimeSpan.Latency.AverageWriteMilliseconds
        $sumAvgTotalLatencyForAllXml += $x.Results.TimeSpan.Latency.AverageTotalMilliseconds
        $totalXml += 1

        # extract the subset of latency percentiles as specified above in $l
        $h = @{}
        $x.Results.TimeSpan.Latency.Bucket |% { $h[$_.Percentile] = $_ }

        $ls = $l |% {
            $b = $h[$_]
            if ($b.ReadMilliseconds) { $b.ReadMilliseconds } else { "" }
            if ($b.WriteMilliseconds) { $b.WriteMilliseconds } else { "" }
        }

        # Sum of 95th percentile read/write latency
        $lat95th = $h[[String]95]
        if ($lat95th.ReadMilliseconds) { $sum95thReadLatencyForAllXml += $lat95th.ReadMilliseconds }
        if ($lat95th.WriteMilliseconds) { $sum95thWriteLatencyForAllXml += $lat95th.WriteMilliseconds }
        if ($lat95th.TotalMilliseconds) { $sum95thTotalLatencyForAllXml += $lat95th.TotalMilliseconds }

        # sum read and write iops across all threads and targets
        $ri = ($x.Results.TimeSpan.Thread.Target |
                measure -sum -Property ReadCount).Sum
        $wi = ($x.Results.TimeSpan.Thread.Target |
                measure -sum -Property WriteCount).Sum
        $rb = ($x.Results.TimeSpan.Thread.Target |
                measure -sum -Property ReadBytes).Sum
        $wb = ($x.Results.TimeSpan.Thread.Target |
                measure -sum -Property WriteBytes).Sum

        # Block size
        $blockSize = ($x.Results.Profile.TimeSpans.TimeSpan.Targets.Target | Measure -Sum -Property BlockSize).Sum / ($x.Results.Profile.TimeSpans.TimeSpan.Targets.Target | Measure -Sum -Property BlockSize).Count
        $writeRatio = ($x.Results.Profile.TimeSpans.TimeSpan.Targets.Target | Measure -Sum -Property WriteRatio).Sum / ($x.Results.Profile.TimeSpans.TimeSpan.Targets.Target | Measure -Sum -Property WriteRatio).Count
        $readRatio = (100 - $writeRatio)
        $threadCount = $x.Results.TimeSpan.ThreadCount #($x.Results.Profile.TimeSpans.TimeSpan.Targets.Target | Measure -Sum -Property ThreadCount).Sum / ($x.Results.Profile.TimeSpans.TimeSpan.Targets.Target | Measure -Sum -Property ThreadCount).Count
        $qd = ($x.Results.Profile.TimeSpans.TimeSpan.Targets.Target | Measure -Sum -Property RequestCount).Sum / ($x.Results.Profile.TimeSpans.TimeSpan.Targets.Target | Measure -Sum -Property RequestCount).Count
        $cpuUtilization = $x.Results.TimeSpan.CpuUtilization.Average.UsagePercent

        # Add VM stats in Azure Table
        if ($StorageTable -ne $null) {
            try {
                Add-TableEntity -Table $StorageTable -PartitionKey $ExecutionId -RowKey "$vname-Iteration-$Iteration" -Iteration $Iteration -CpuUtilization $cpuUtilization -QueueDepth $qd -NumberOfThreads $threadCount -BlockSize $blockSize -ReadWriteRatio $readRatio/$writeRatio -RandomIoPercentage $RandomIoPercentage -Total_IOPS ("{0:N0}" -f [float](($ri / $t) + ($wi / $t))) -Read_IOPS ("{0:N0}" -f [float]($ri / $t)) -Write_IOPS ("{0:N0}" -f [float]($wi / $t)) -Total_AvgLatency ("{0:N2}" -f [float]($x.Results.TimeSpan.Latency.AverageTotalMilliseconds)) -Read_AvgLatency  ("{0:N2}" -f [float]($x.Results.TimeSpan.Latency.AverageReadMilliseconds)) -Write_AvgLatency ("{0:N2}" -f [float]($x.Results.TimeSpan.Latency.AverageWriteMilliseconds)) -Total_95thPercentile_AvgLatency ("{0:N2}" -f [float]($lat95th.TotalMilliseconds)) -Read_95thPercentile_AvgLatency ("{0:N2}" -f [float]($lat95th.ReadMilliseconds)) -Write_95thPercentile_AvgLatency ("{0:N2}" -f [float]($lat95th.WriteMilliseconds)) | Out-Null
            } catch [Exception] {
                Log-Warning -Message "Exception in adding Azure Storage Table entry. $_"
            }
        }

        # Sum of avg of read/write iops
        $sumAvgReadIopsForAllXml += ($ri / $t)
        $sumAvgWriteIopsForAllXml += ($wi / $t)

        # output tab-separated fields. note that with runs specified on the command
        # line, only a single write ratio, outstanding request count and blocksize
        # can be specified, so sampling the one used for the first thread is
        # sufficient.
        (($system,
            $x.Results.TimeSpan.CpuUtilization.Average.UsagePercent,
            $x.Results.Profile.TimeSpans.TimeSpan.Targets.Target.WriteRatio,
            $x.Results.TimeSpan.ThreadCount,
            $x.Results.Profile.TimeSpans.TimeSpan.Targets.Target.RequestCount,
            $x.Results.Profile.TimeSpans.TimeSpan.Targets.Target.BlockSize,
            # calculate iops
            ($ri / $t),
            ($rb / $t),
            ($wi / $t),
            ($wb / $t),
            $x.Results.TimeSpan.Latency.AverageReadMilliseconds,
            $x.Results.TimeSpan.Latency.AverageWriteMilliseconds
            ) -join "`t"),
        ($ls -join "`t") -join "`t"
        cd $pwdir
    } | Out-File $OutPath -Encoding ASCII -Width 9999 -Append

    $avgAvgReadLatencyForAllXml = $sumAvgReadLatencyForAllXml/$totalXml
    $avgAvgWriteLatencyForAllXml = $sumAvgWriteLatencyForAllXml/$totalXml
    $avgAvgTotalLatencyForAllXml = $sumAvgTotalLatencyForAllXml/$totalXml

    $avg95thReadLatencyForAllXml = $sum95thReadLatencyForAllXml/$totalXml
    $avg95thWriteLatencyForAllXml = $sum95thWriteLatencyForAllXml/$totalXml
    $avg95thTotalLatencyForAllXml = $sum95thTotalLatencyForAllXml/$totalXml

    # Create custom latency and iops result object
    $customResult = "" | Select-Object AvgReadLat, AvgWriteLat, AvgTotalLat, Avg95thReadLat, Avg95thWriteLat, Avg95thTotalLat, ReadIops, WriteIops, TotalIops, BlockSize, WriteRatio, VmCount
    $customResult.AvgReadLat = $avgAvgReadLatencyForAllXml
    $customResult.AvgWriteLat = $avgAvgWriteLatencyForAllXml
    $customResult.AvgTotalLat = $avgAvgTotalLatencyForAllXml
    $customResult.Avg95thReadLat = $avg95thReadLatencyForAllXml
    $customResult.Avg95thWriteLat = $avg95thWriteLatencyForAllXml
    $customResult.Avg95thTotalLat = $avg95thTotalLatencyForAllXml
    $customResult.ReadIops = $sumAvgReadIopsForAllXml
    $customResult.WriteIops = $sumAvgWriteIopsForAllXml
    $customResult.TotalIops = ($sumAvgReadIopsForAllXml + $sumAvgWriteIopsForAllXml)
    $customResult.BlockSize = $blockSize
    $customResult.WriteRatio = $writeRatio
    $customResult.VmCount = $totalXml

    return $customResult
}

function Generate-HtmlSummary
{
    param
    (
        [Parameter(Mandatory = $true)]
        $ResultSummary,
        [Parameter(Mandatory = $true)]
        $BestIteration,
        [Parameter(Mandatory = $true)]
        $FixedIteration,
        [Parameter(Mandatory = $true)]
        $FilePath
    )

    #create html file
    try {
        Log-Info -Message "Generating HTML Test Result Summary."
        $resTable = @()

        #header
        $style = "<style>"
        $style +=  "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
        $style +=  "TH{border-width: 1px;padding: 2px;border-style: solid;border-color: black;}"
        $style +=  "TD{border-width: 1px;padding: 2px;border-style: solid;border-color: black;}"
        $style +=  "</style>"

        foreach($res in $ResultSummary) {
            $resBlob = New-Object System.Object

            $resBlob | Add-Member -type NoteProperty -name "Iteration" -value $res.iteration
            $resBlob | Add-Member -type NoteProperty -name "Total Outstanding IO Requests" -value $res.totalQD
            $roundedVal = [math]::Round($res.summary.TotalIops)
            $resBlob | Add-Member -type NoteProperty -name "Total IOPS" -value $roundedVal
            $roundedVal = "{0:N2}" -f [float]($res.summary.AvgTotalLat)
            $resBlob | Add-Member -type NoteProperty -name "Average Total Latency" -value $roundedVal
            $roundedVal = "{0:N2}" -f [float]($res.summary.Avg95thTotalLat)
            $resBlob | Add-Member -type NoteProperty -name "Average 95th Total Latency" -value $roundedVal
            $roundedVal = [math]::Round($res.summary.ReadIops)
            $resBlob | Add-Member -type NoteProperty -name "Read IOPS" -value $roundedVal
            $roundedVal = "{0:N2}" -f [float]($res.summary.AvgReadLat)
            $resBlob | Add-Member -type NoteProperty -name "Average Read Latency" -value $roundedVal
            $roundedVal = "{0:N2}" -f [float]($res.summary.Avg95thReadLat)
            $resBlob | Add-Member -type NoteProperty -name "Average 95th Read Latency" -value $roundedVal
            $roundedVal = [math]::Round($res.summary.WriteIops)
            $resBlob | Add-Member -type NoteProperty -name "Write IOPS" -value $roundedVal
            $roundedVal = "{0:N2}" -f [float]($res.summary.AvgWriteLat)
            $resBlob | Add-Member -type NoteProperty -name "Average Write Latency" -value $roundedVal
            $roundedVal = "{0:N2}" -f [float]($res.summary.Avg95thWriteLat)
            $resBlob | Add-Member -type NoteProperty -name "Average 95th Write Latency" -value $roundedVal

            $resBlob | Add-Member -type NoteProperty -name "DiskSpd Threads" -value $res.threads
            $resBlob | Add-Member -type NoteProperty -name "DiskSpd IO Queue Depth" -value $res.qd
            $resBlob | Add-Member -type NoteProperty -name "DiskSpd Block Size (Bytes)" -value $res.blockSize
            $resBlob | Add-Member -type NoteProperty -name "DiskSpd Random IO %" -value $res.randomIoPercentage
            $resBlob | Add-Member -type NoteProperty -name "DiskSpd Random IO Distribution (IO%/LOC%)" -value $res.randomIoDistribution
            $resBlob | Add-Member -type NoteProperty -name "Total Data Disks" -value ($DataDisks * $res.vmCount)
            $resBlob | Add-Member -type NoteProperty -name "Total VMs" -value $res.vmCount
            $resTable += $resBlob
        }

        $results = $resTable |  ConvertTo-HTML -Head $style

        #Get headers
        $headers = [regex]::Matches(($results | out-string), "<th>(.*?)</th>")
        #Find index of CPU-header
        $iteration = $headers | ForEach-Object -Begin { $i = 0 } -Process { if($_.Groups[1].Value -eq "Iteration") { $i } else { $i++ } }

        if ($BestIteration -ge 0) {
            # Regex Replace MatchEvaluator
            $BestIterationME = {
                param($match)
                # If Group 2 (Iteration) = BestIteration
                if([double]::Parse($match.Groups[2].Value) -eq $BestIteration) {
                    #Add red text-style to row
                    '<tr style="background-color : lightgreen;">{0}' -f $match.Groups[1].Value
                } else {
                    #Return org. value
                    $match.Value
                }

            }

            #Regex replace all lines
            $results = $results | Foreach-Object { [regex]::Replace($_, "^<tr>((?:<td>[^<]*?<\/td>){$iteration}<td>(\d.*?)<\/td><.*)", $BestIterationME) }
        }

        if ($FixedIteration -ge 0) {
            # Regex Replace MatchEvaluator
            $FixedIterationME = {
                param($match)
                # If Group 2 (Iteration) = FixedIteration
                if([double]::Parse($match.Groups[2].Value) -eq $FixedIteration) {
                    #Add red text-style to row
                    '<tr style="background-color : lightblue;">{0}' -f $match.Groups[1].Value
                } else {
                    #Return org. value
                    $match.Value
                }

            }

            #Regex replace all lines
            $results = $results | Foreach-Object { [regex]::Replace($_, "^<tr>((?:<td>[^<]*?<\/td>){$iteration}<td>(\d.*?)<\/td><.*)", $FixedIterationME) }
        }

        $results | Out-File -FilePath $FilePath -Encoding ASCII
        Log-Info -Message "Generated HTML Test Result Summary: $FilePath"

    }
    catch {
        Log-Warning -Message "Error generating summary html $FilePath $_"
    }
}

function Get-IoStormMode
{
    param (
        [Parameter(Mandatory = $true)]
        [bool]$RunFixedIoLatencyTestAfterGoalSeek,
        [Parameter(Mandatory = $true)]
        [int32]$FixedIops
    )

    if ($RunFixedIoLatencyTestAfterGoalSeek -eq $true -and $FixedIops -ne 0) {
        $ioStormMode = "GoalSeekFixedIops"
    } elseif ($RunFixedIoLatencyTestAfterGoalSeek -eq $false -and $FixedIops -ne 0) {
        $ioStormMode = "FixedIops"
    } else {
        $ioStormMode = "GoalSeek"
    }

    return $ioStormMode
}

function Get-LatencyResult
{
    param (
        [Parameter(Mandatory = $true)]
        $IoResultIterationShare,
        [Parameter(Mandatory = $true)]
        $VMIoResultFile,
        [Parameter(Mandatory = $true)]
        $StorageTable,
        [Parameter(Mandatory = $true)]
        $ExecutionId,
        [Parameter(Mandatory = $true)]
        $Iteration,
        [Parameter(Mandatory = $true)]
        $VMCount,
        [Parameter(Mandatory = $true)]
        $QueueDepth,
        [Parameter(Mandatory = $true)]
        $NumThreads,
        [Parameter(Mandatory = $true)]
        $RandomIoPercentage,
        [Parameter(Mandatory = $true)]
        $RandomIoDistribution,
        [Parameter(Mandatory = $true)]
        $BlockSize
    )

    $res = Analyze-DiskspdResultXml -InputPath $IoResultIterationShare -OutPath $VMIoResultFile -StorageTable $StorageTable -ExecutionId $ExecutionId -Iteration $Iteration -RandomIoPercentage $RandomIoPercentage

    $fullLatencyResults = @{}
    $fullLatencyResults.summary = $res
    #qd is acutally diskspd operations per thread
    $fullLatencyResults.qd = $QueueDepth
    $fullLatencyResults.threads = $NumThreads
    $fullLatencyResults.vmCount = $VMCount
    $fullLatencyResults.totalQD = $VMCount * $NumThreads * $QueueDepth
    $fullLatencyResults.iteration = $Iteration
    $fullLatencyResults.blockSize = $BlockSize
    $fullLatencyResults.randomIoPercentage = $RandomIoPercentage
    $fullLatencyResults.randomIoDistribution = $RandomIoDistribution

    Log-Info -Message "Analyze IO workload iteration $Iteration result succeeded."

    return $fullLatencyResults
}

function Generate-IOSummary
{
    param (
        [Parameter(Mandatory = $true)]
        $LatencyResult,
        [Parameter(Mandatory = $true)]
        $CsvPath,
        [Parameter(Mandatory = $true)]
        $VMIoResultFile,
        [Parameter(Mandatory = $true)]
        $ExecutionId,
        [Parameter(Mandatory = $true)]
        $StorageTable,
        [Parameter(Mandatory = $true)]
        $Iteration,
        [Parameter(Mandatory = $true)]
        $VMCount,
        [Parameter(Mandatory = $true)]
        $DataDisks,
        [Parameter(Mandatory = $true)]
        $QueueDepth,
        [Parameter(Mandatory = $true)]
        $NumThreads,
        [Parameter(Mandatory = $true)]
        $RandomIoPercentage
    )

    $VMCount = $LatencyResult.VmCount

    $avgReadLatency = "{0:N2}" -f [float]$LatencyResult.AvgReadLat
    $avgWriteLatency = "{0:N2}" -f [float]$LatencyResult.AvgWriteLat
    $avgTotalLatency = "{0:N2}" -f [float]$LatencyResult.AvgTotalLat

    $avg95thReadLat = "{0:N2}" -f [float]$LatencyResult.Avg95thReadLat
    $avg95thWriteLat = "{0:N2}" -f [float]$LatencyResult.Avg95thWriteLat
    $avg95thTotalLat= "{0:N2}" -f [float]$LatencyResult.Avg95thTotalLat

    $tReadIops = "{0:N0}" -f [float]$LatencyResult.ReadIops
    $tWriteIops = "{0:N0}" -f [float]$LatencyResult.WriteIops
    $tTotalIops = "{0:N0}" -f [float]$LatencyResult.TotalIops

    $blockSize = "{0:N0}" -f [float]$LatencyResult.BlockSize
    $writeRatio = "{0:N0}" -f [float]$LatencyResult.WriteRatio
    $readRatio = (100 - $writeRatio)

    $resTxt = "Iteration $Iteration, Overall-IOPS: (Total: $tTotalIops, Read: $tReadIops, Write: $tWriteIops), AvgLatencyInMsec: (Total: $avgTotalLatency, Read: $avgReadLatency, Write: $avgWriteLatency), Avg95thPercLatencyInMsec: (Total: $avg95thTotalLat, Read: $avg95thReadLat, Write: $avg95thWriteLat), NumberOfVMs: $VMCount, QueueDepth: $QueueDepth, NumThreads: $NumThreads, BlockSize: $blockSize, ReadWriteRatio: $readRatio/$writeRatio, RandomIoPercentage: $RandomIoPercentage"
    $resTxt | Out-File $VMIoResultFile -Encoding ASCII -Append
    Log-Info -Message $resTxt

    $nocommaReadIops = "{0:F0}" -f $LatencyResult.ReadIops
    $nocommaWriteIops = "{0:F0}" -f $LatencyResult.WriteIops
    $nocommaTotalIops = "{0:F0}" -f $LatencyResult.TotalIops
    $nocommaBlocksize =  "{0:F0}" -f $LatencyResult.BlockSize

    # Summary
    Add-CsvRow -CSvPath $CsvPath -RunName "Summary-Iteration-$Iteration" -Iteration $Iteration -NumberOfVMs $VMCount -QueueDepth $QueueDepth -NumberOfThreads $NumThreads -BlockSize $nocommaBlocksize -ReadWriteRatio $readRatio/$writeRatio -RandomIoPercentage $RandomIoPercentage -Total_IOPS $nocommaTotalIops -Read_IOPS $nocommaReadIops -Write_IOPS $nocommaWriteIops -Total_AvgLatency $avgTotalLatency -Read_AvgLatency $avgReadLatency -Write_AvgLatency $avgWriteLatency -Total_95thPercentile_AvgLatency $avg95thTotalLat -Read_95thPercentile_AvgLatency $avg95thReadLat -Write_95thPercentile_AvgLatency $avg95thWriteLat -NumberOfDisksPerVM $DataDisks

    # Add results to the Azure storage table
    if ($StorageTable -ne $null) {
        try {
            Add-TableEntity -Table $StorageTable -PartitionKey $ExecutionId -RowKey "Summary-Iteration-$Iteration" -Iteration $Iteration -Details $resTxt -NumberOfVMs $VMCount -QueueDepth $QueueDepth -NumberOfThreads $NumThreads -BlockSize $blockSize -ReadWriteRatio $readRatio/$writeRatio -RandomIoPercentage $RandomIoPercentage -Total_IOPS $tTotalIops -Read_IOPS $tReadIops -Write_IOPS $tWriteIops -Total_AvgLatency $avgTotalLatency -Read_AvgLatency $avgReadLatency -Write_AvgLatency $avgWriteLatency -Total_95thPercentile_AvgLatency $avg95thTotalLat -Read_95thPercentile_AvgLatency $avg95thReadLat -Write_95thPercentile_AvgLatency $avg95thWriteLat -NumberOfDisksPerVM $DataDisks | Out-Null
            Log-Info -Message "Added Azure storage table entry for row Summary-Iteration-$Iteration"
        } catch {
            Log-Warning -Message "Adding Azure storage table entry for row Summary-Iteration-$Iteration failed. $_"
        }
    }
    else {
        Log-Warning -Message "Azure storage table object is null"
    }

    return $resTxt
}

function Wait-VMIOWorkload
{
    param (
        [Parameter(Mandatory = $true)]
        $IoDuration,
        [Parameter(Mandatory = $true)]
        $Iteration,
        [Parameter(Mandatory = $true)]
        $IoResultIterationShare,
        [Parameter(Mandatory = $true)]
        $IoResultExpectedFiles
    )

    $noOfRetries = [int]($IoDuration * 2 / 30)
    $ioWorkloadDidSucceed = $false
    Log-Info -Message "Waiting for IO workload to finish. ETA: $((Get-Date).AddSeconds($IoDuration))"
    while($noOfRetries -gt 0) {
        Log-Info -Message "Waiting for IO workload iteration $($Iteration)"
        $existingFiles = Get-ChildItem -Path $IoResultIterationShare -Filter *.xml
        if ($existingFiles.Count -ge $IoResultExpectedFiles) {
            $ioWorkloadDidSucceed = $true
            Log-Info -Message "IO workload iteration $Iteration succeeded."
            break
        }

        Start-Sleep -Seconds 30
        $noOfRetries--
    }

    return $ioWorkloadDidSucceed
}

function Upload-TestResource
{
    param (
        [Parameter(Mandatory = $true)]
        $ResName,
        [Parameter(Mandatory = $true)]
        $ContainName,
        [Parameter(Mandatory = $true)]
        $StorageContext,
        [Parameter(Mandatory = $true)]
        $FilePath
    )

    $blob = Get-AzureStorageBlob -Context $StorageContext -Blob $ResName -Container $ContainName -ErrorAction SilentlyContinue
    if(-not $blob) {
        $blob = Set-AzureStorageBlobContent -Context $StorageContext -File $FilePath -Blob $ResName -Container $ContainName -Force -ErrorAction Stop
    }

    $sas = New-AzureStorageBlobSASToken -Context $StorageContext -Container $ContainName -Blob $ResName -Permission r
    $resUri = $blob.ICloudBlob.Uri.AbsoluteUri + $sas
    Log-Info -Message "Uploaded test resource $ResName, Uri: $resUri"

    return $resUri
}

##################
# Main Function
##################
function Start-IoStorm {
    param(
        [Parameter(Mandatory = $true)]
        [String]$ARMEndpoint,
        [Parameter(Mandatory = $true)]
        [PSCredential]$AdminCredential,
        [Parameter(Mandatory = $true)]
        [String]$TenantId,
        [Parameter(Mandatory = $false)]
        [String]$ResourcePath = $PSScriptRoot,
        [Parameter(Mandatory = $false)]
        [String]$OutputPath = $((Resolve-Path .).Path),
        [Parameter(Mandatory = $false)]
        [String]$OutputResourceGroup = $null,
        [Parameter(Mandatory = $false)]
        [String]$OutputStorageAccountName = $null,
        [Parameter(Mandatory = $false)]
        [String]$ResourceGroup = $null,
        [Parameter(Mandatory = $false)]
        [int]$VMCount = 0, # If you set it to 0, it will be calculated automatically
        [Parameter(Mandatory = $false)]
        [String]$VMSize = "Standard_DS3_v2",
        [Parameter(Mandatory = $false)]
        [String]$VMOsSku = "2016-Datacenter",
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 1023)]
        [int]$DataDisks = 0, # Should less than the max number of data disks for the VM size, if you set it to 0, it will be calculated automatically
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 1023)]
        [int]$DataDiskSizeInGB = 0, # If you set it to 0, it will be calculated automatically
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 10240)]
        [int]$VMIoMaxLatency = 30,
        [Parameter(Mandatory = $false)]
        [ValidateRange(10, 90)]
        [int]$StorageUsagePercentage = 80,
        [Parameter(Mandatory = $false)]
        [int]$FixedIops = 0,
        [Parameter(Mandatory = $false)]
        [switch]$RestartRun,
        [Parameter(Mandatory = $false)]
        [switch]$RunFixedIoLatencyTestAfterGoalSeek,
        [Parameter(Mandatory = $false)]
        [switch]$SkipCleanUp,
        ### Diskspd PARAMS ###
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 1024)]
        [int]$IoMinQueueDepth = 1, # IO queue depth
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 1024)]
        [int]$IoThreads = 0, # If you set it to 0, it will be calculated automatically
        [Parameter(Mandatory = $false)]
        [int]$IoDurationInSec = 1200,
        [Parameter(Mandatory = $false)]
        [int]$IoBlockSizeInBytes = 4096,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0,100)]
        [int]$IoWritePercentage = 50,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0,100)]
        [int]$IoRandomIoPercentage = 70,
        [Parameter(Mandatory = $false)]
        [String]$IoRandomIoDistribution = "90/10" # If you don't want to control the random io distribution, please set it to null
    )
    
    $ProgressPreference = 'SilentlyContinue'
    $ErrorActionPreference = 'Stop'
    
    # Use TLS 1.2
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    
    $startDate = Get-Date
    # Log file
    $logFileName = "IoStormController.log"

    # Check parameters
    if ((Test-Path $OutputPath) -eq $false) {
        $OutputPath = (New-Item -Path $OutputPath -ItemType Directory -Force -Verbose -ErrorAction Stop).FullName
    } else {
        $OutputPath = (Resolve-Path $OutputPath).Path
    }

    Log-Info -Message "Results and logs will be stored in $OutputPath"

    if ((Test-Path $ResourcePath) -eq $false) {
        Log-Warning -Message "The resource path $ResourcePath is invalid, please double check!" -Throw
    } else {
        $ResourcePath = (Resolve-Path $ResourcePath).Path
        $armTemplateFile = Join-Path -Path $ResourcePath -ChildPath "workloaddeployment.json"
        if ((Test-Path $armTemplateFile) -eq $false) {
            Log-Warning -Message "Unable to access the ARM template file workloaddeployment.json in resource path $ResourcePath, please double check!" -Throw
        }

        $controllerVmDeploymentScript = "VMIOController.ps1"
        $controllerVmDeploymentScriptFile = Join-Path -Path $ResourcePath -ChildPath "VMIOController\$controllerVmDeploymentScript"
        if ((Test-Path $controllerVmDeploymentScriptFile) -eq $false) {
            Log-Warning -Message "Unable to access the controller VM deployment script file VMIOController\$controllerVmDeploymentScript in resource path $ResourcePath, please double check!" -Throw
        }
        
        $controllerVmTaskScript = "VMIOControllerTask.ps1"
        $controllerVmTaskScriptFile = Join-Path -Path $ResourcePath -ChildPath "VMIOController\$controllerVmTaskScript"
        if ((Test-Path $controllerVmTaskScriptFile) -eq $false) {
            Log-Warning -Message "Unable to access the controller VM task script file VMIOController\$controllerVmTaskScript in resource path $ResourcePath, please double check!" -Throw
        }

        $workloadVmDeploymentScript = "VMIOWorkload.ps1"
        $workloadVmDeploymentScriptFile = Join-Path -Path $ResourcePath -ChildPath "VMIOWorkload\$workloadVmDeploymentScript"
        if ((Test-Path $workloadVmDeploymentScriptFile) -eq $false) {
            Log-Warning -Message "Unable to access the workload VM deployment script file VMIOWorkload\$workloadVmDeploymentScript in resource path $ResourcePath, please double check!" -Throw
        }

        $workloadVmTaskScript = "VMIOWorkloadTask.ps1"
        $workloadVmTaskScriptFile = Join-Path -Path $ResourcePath -ChildPath "VMIOWorkload\$workloadVmTaskScript"
        if ((Test-Path $workloadVmTaskScriptFile) -eq $false) {
            Log-Warning -Message "Unable to access the workload VM task script file VMIOWorkload\$workloadVmTaskScript in resource path $ResourcePath, please double check!" -Throw
        }

        $workloadVmDiskSpd = "diskspd.exe"
        $workloadVmDiskSpdFile = Join-Path -Path $ResourcePath -ChildPath "VMIOWorkload\$workloadVmDiskSpd"
        if ((Test-Path $workloadVmDiskSpdFile) -eq $false) {
            Log-Warning -Message "Unable to access the workload VM DiskSpd file VMIOWorkload\$workloadVmDiskSpd in resource path $ResourcePath, please double check!" -Throw
        }
    }
    
    if (-not $ResourceGroup) {
        if ($RestartRun -eq $true) {
            Log-Warning -Message "Please specify the ResourceGroup if you want to rerun." -Throw
        }

        $ResourceGroup = "IoStorm$($startDate.ToString('MMdd'))"
    }

    Log-Info -Message "Using Resource Group $ResourceGroup for workload."

    if (-not $OutputResourceGroup) {
        $OutputResourceGroup = $ResourceGroup
    }

    if (-not $OutputStorageAccountName) {
        $OutputStorageAccountName = "iostormoutsa$($startDate.ToString('MMddHHmm'))"
    }

    $OutputStorageAccountName = $OutputStorageAccountName.ToLower()

    Log-Info -Message "Using Storage Account $OutputStorageAccountName under Resource Group $OutputResourceGroup for output."

    $localPath = Join-Path -Path $OutputPath -ChildPath "IoStorm$($startDate.ToString('MMddHHmm'))"
    $logFilePath = "$localPath\$logFileName"

    if ((Test-Path $localPath) -eq $false) {
        New-Item -Path $localPath -ItemType Directory -Force -Verbose -ErrorAction Stop | Out-Null
    } else {
        if ($RestartRun -eq $false) {
            Get-ChildItem -Path "$localPath\" -Recurse | Remove-Item -Force -Verbose
        }
    }

    try {
        Start-Transcript -Path $logFilePath -Append -Force

        # Get the admin ARM endpoint.
        $AdminARMEndpoint = $ARMEndpoint.ToLower().Trim("/").Replace("adminmanagement", "management").Replace("management", "adminmanagement")

        # Deploy workload
        Login-AdminARM -AdminARMEndpoint $AdminARMEndpoint -AdminCredential $AdminCredential -TenantId $TenantId

        $vmSizeConfig = Get-AzureRmVMSize -Location (Get-AzureRmLocation).Location -ErrorAction Stop | Where-Object {$_.Name -eq $VMSize} | Select-Object -First 1

        Log-Info "Using $($VMSize) VM, which has $($vmSizeConfig.NumberOfCores) cores and up to $($vmSizeConfig.MaxDataDiskCount) data disks."
        if ($DataDisks -gt $vmSizeConfig.MaxDataDiskCount) {
            Log-Warning -Message "Unable to deploy $($DataDisks) data disks on $($VMSize) VM." -Throw
        }

        if ($DataDisks -eq 0) {
            $DataDisks = $vmSizeConfig.MaxDataDiskCount
            Log-Info -Message "Adjust DataDisks to $($DataDisks)"
        }

        if ($RestartRun -eq $false) {
            $scaleUnitName = "s-cluster"
            $ss = Get-AzsStorageSubSystem -ScaleUnit $scaleUnitName | Select-Object -First 1
            $allVols = Get-AzsVolume -ScaleUnit $scaleUnitName -StorageSubSystem $ss.Name
            $allObjStoreVols = $allVols | Where-Object {$_.VolumeLabel -like "*ObjStore*"}
            $totRemainingCapacityGB = ($allObjStoreVols | Measure-Object -Property RemainingCapacityGB -Sum).Sum
            Log-Info -Message "Found $($allObjStoreVols.Count) Objstore volumes, total remaining capacity $($totRemainingCapacityGB) GB"

            $volUsage = $StorageUsagePercentage / 100
            $defaultDataDiskSizeInGB = 256
            $adjustDataDiskSize = $false
            if ($DataDiskSizeInGB -eq 0) {
                $adjustDataDiskSize = $true
                $DataDiskSizeInGB = $defaultDataDiskSizeInGB
            }

            $totDisks = [math]::Ceiling(($totRemainingCapacityGB * $volUsage) / $DataDiskSizeInGB)

            $defaultVMCount = $allObjStoreVols.Count * [math]::Ceiling(112 / $DataDisks) # equals to (the number of nodes) * (112 / (the number of data disks per VM))
            $minVMCount = [math]::Ceiling(($totDisks / $DataDisks))
            if (($minVMCount -gt $defaultVMCount) -and ($VMCount -eq 0)) {
                $VMCount = $minVMCount
                Log-Info -Message "Adjust VMCount to $VMCount to meet minimum data disk requirement ($($totDisks) * $($DataDiskSizeInGB) GB)."
            } else {
                if ($VMCount -eq 0) {
                    $VMCount = $defaultVMCount
                    Log-Info -Message "Adjust VMCount to $VMCount"
                }

                if ($adjustDataDiskSize -eq $true) {
                    $DataDiskSizeInGB = [math]::Min(1023, [math]::Ceiling(($totRemainingCapacityGB * $volUsage) / $DataDisks / $VMCount))
                    Log-Info -Message "Adjust DataDiskSizeInGB to $DataDiskSizeInGB"
                }
            }

            Log-Info -Message "Will deploy $($VMCount) workload VMs and $($DataDisks) (* $($DataDiskSizeInGB) GB) data disks per VM."

            if (Get-AzureRmResourceGroup -Name $ResourceGroup -Location (Get-AzureRmLocation).Location -ErrorAction SilentlyContinue) {
                Remove-AzureRmResourceGroup -Name $ResourceGroup -Force -Verbose -ErrorAction Stop | Out-Null
            }

            New-AzureRMResourceGroup -Name $ResourceGroup -Location (Get-AzureRmLocation).Location -Force -Verbose -ErrorAction Stop | Out-Null

            $resStorageAccountName = "iostormsa$($startDate.ToString('MMddHHmm'))"
            $resContainName = "iostormres$($startDate.ToString('MMddHHmm'))"
            $resStorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroup -Name $resStorageAccountName -ErrorAction SilentlyContinue
            if(-not $resStorageAccount) {
                $resStorageAccount = New-AzureRmStorageAccount -ResourceGroupName $ResourceGroup -Name $resStorageAccountName -SkuName Standard_LRS -Location (Get-AzureRmLocation).Location -Verbose -ErrorAction Stop
            }

            $resStorageCtx = $resStorageAccount.Context
            $resContainer = Get-AzureStorageContainer -Name $resContainName -Context $resStorageCtx -ErrorAction SilentlyContinue
            if(-not $resContainer) {
                $resContainer = New-AzureStorageContainer -Name $resContainName -Context $resStorageCtx -ErrorAction Stop
            }
            
            $controllerVmDeploymentScriptUri = Upload-TestResource -ResName $controllerVmDeploymentScript -ContainName $resContainName -StorageContext $resStorageCtx -FilePath $controllerVmDeploymentScriptFile
            $controllerVmTaskScriptUri = Upload-TestResource -ResName $controllerVmTaskScript -ContainName $resContainName -StorageContext $resStorageCtx -FilePath $controllerVmTaskScriptFile
            $workloadVmDeploymentScriptUri = Upload-TestResource -ResName $workloadVmDeploymentScript -ContainName $resContainName -StorageContext $resStorageCtx -FilePath $workloadVmDeploymentScriptFile
            $workloadVmTaskScriptUri = Upload-TestResource -ResName $workloadVmTaskScript -ContainName $resContainName -StorageContext $resStorageCtx -FilePath $workloadVmTaskScriptFile
            $workloadVmDiskSpdUri = Upload-TestResource -ResName $workloadVmDiskSpd -ContainName $resContainName -StorageContext $resStorageCtx -FilePath $workloadVmDiskSpdFile

            New-AzureRMResourceGroupDeployment -ResourceGroupName $ResourceGroup -TemplateFile $armTemplateFile `
                -vmCount $VMCount `
                -vmOsSku $VMOsSku `
                -vmSize $VMSize `
                -vmDataDiskSizeInGB $DataDiskSizeInGB `
                -vmDataDiskCount $DataDisks `
                -controllerVmDeploymentScriptUri $controllerVmDeploymentScriptUri `
                -controllerVmTaskScriptUri $controllerVmTaskScriptUri `
                -workloadVmDeploymentScriptUri $workloadVmDeploymentScriptUri `
                -workloadVmTaskScriptUri $workloadVmTaskScriptUri `
                -workloadVmDiskSpdUri $workloadVmDiskSpdUri `
                -resourceStorageAccountName $resStorageAccountName `
                -Verbose -ErrorAction Stop | Out-Null

            Log-Info -Message "ARM deployment completed successfully."
        } else {
            $allVMs = Get-AzureRmVM -ResourceGroupName $ResourceGroup -Status -ErrorAction Stop
            $VMCount = ($allVMs | Where-Object {($_.Name -ne "vm$ResourceGroup") -and ($_.PowerState -like "*running*")}).Count
            if ($VMCount -lt 1) {
                Log-Warning -Message "No enough workload VMs in the resource group $ResourceGroup are online"
            }

            $controllerVMCount = ($allVMs | Where-Object {($_.Name -eq "vm$ResourceGroup") -and ($_.PowerState -like "*running*")}).Count
            if ($controllerVMCount -lt 1) {
                Log-Warning -Message "Controller VM in the resource group $ResourceGroup is offline."
            }

            Log-Info -Message "Found $VMCount workload VMs in the resource group $ResourceGroup are online. Restarting..."
            $restartJobs = $allVMs | Restart-AzureRmVM -ErrorAction Stop -AsJob
            $restartJobs | Wait-Job | Out-Null
            if (($restartJobs | Where-Object {$_.State -eq "Completed"}).Count -eq $allVMs.Count) {
                Log-Info -Message "VMs have been successfully restarted." 
            } else {
                Log-Warning -Message "Failed to restart VMs, please double check or redeploy." -Throw
            }
        }

        # Wait 2 mins for background task on the VMs
        Log-Info -Message "Wait 2 minutes for the background task on the VMs."
        Start-Sleep -Seconds 120

        # Get Controller VM Ip and create PS remote session.
        $ioStormControllerVMName = "vm" + $ResourceGroup
        $controllerVm = Get-AzureRMVM -Name $ioStormControllerVMName -ResourceGroupName $ResourceGroup
        $controllerVmNIC = Get-AzureRMNetworkInterface | Where-Object {$_.Id -eq $controllerVm.NetworkProfile.NetworkInterfaces[0].Id}
        $controllerVmPipName = $controllerVmNIC.IpConfigurations[0].PublicIpAddress.Id.Split('/') | Select-Object -Last 1
        Log-Info -Message "Try to get public ip address for $controllerVmPipName"
        $controllerVmPipAddress = (Get-AzureRMPublicIpAddress -ResourceGroupName $ResourceGroup -Name $controllerVmPipName).IpAddress
        Log-Info -Message "Got public ip address $controllerVmPipAddress for $ioStormControllerVMName"

        $controllerVmAdmin = "vmadministrator"
        $controllerVmPW = "Subscription#" + $((Get-AzureRMSubscription -SubscriptionName "Default Provider Subscription").Id)

        $smbshare = "\\$ControllerVmPipAddress\smbshare"

        if ((Setup-IoStormControllerShare -ControllerShare $smbshare -TimeoutInSeconds 3600 -VMAdminUserName $controllerVmAdmin -VMAdminPassword $controllerVmPW) -eq $false) {
            Log-Warning -Message "Failed to connect controller share $smbshare" -Throw
        }

        Log-Info -Message "Connected to controller share $smbshare"

        # Setup storage for output
        if (-not (Get-AzureRmResourceGroup -Name $OutputResourceGroup -Location (Get-AzureRmLocation).Location -ErrorAction SilentlyContinue)) {
            New-AzureRMResourceGroup -Name $OutputResourceGroup -Location (Get-AzureRmLocation).Location -Force -Verbose -ErrorAction Stop | Out-Null
        }
        
        if (-not (Get-AzureRmStorageAccount -ResourceGroupName $OutputResourceGroup -Name $OutputStorageAccountName -ErrorAction SilentlyContinue)) {
            New-AzureRmStorageAccount -ResourceGroupName $OutputResourceGroup -Name $OutputStorageAccountName -SkuName Standard_LRS -Location (Get-AzureRmLocation).Location -Verbose -ErrorAction Stop | Out-Null
        }
        
        $outputStorageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $OutputResourceGroup -Name $OutputStorageAccountName)[0].Value
        $outputStorageEndpoint = (Get-AzureRmStorageAccount -ResourceGroupName $OutputResourceGroup -Name $OutputStorageAccountName).PrimaryEndpoints.Blob        
        if ($outputStorageEndpoint.Contains("blob")) {
            $outputStorageEndpoint = $outputStorageEndpoint.Substring($outputStorageEndpoint.LastIndexOf("blob") + "blob".Length + 1)
            $outputStorageEndpoint = $outputStorageEndpoint.replace("/", "")
            # If storage endpoint have a port number remove portion after :3456 e.g. http://saiostorm.blob.azurestack.local:3456/
            if ($outputStorageEndpoint.Contains(":")) {
                $outputStorageEndpoint = $outputStorageEndpoint.Substring(0, $outputStorageEndpoint.LastIndexOf(":"))
            }
        }

        # Setup paths
        $csvPath = "$localPath\IoData.csv"
        $fixedIopsCsvPath = "$localPath\FixedIoData.csv"
        $statusFilePath = "$localPath\IoStormStatus.log"
        $vmioResultFile = "$localPath\IoStormResults.log"
        $resultHtmlPath = "$localPath\IoStormResults.html"
        $ioPreSyncShare = "$smbshare\iopresync"
        # Sync signal to start IO pre-sync from controller vm
        $ioPreSyncStartSignalFile = "$smbshare\iopresyncstart.txt"
        # Start IO workload signal file (also indicates pre IO workload sync succeed singal)
        $ioWorkloadStartSignalFile = "$smbshare\ioworkloadstart-"
        # Controller VMIO result directory
        $ioResultShare = "$smbshare\ioresult"

        $ioStormMode = Get-IoStormMode -RunFixedIoLatencyTestAfterGoalSeek $RunFixedIoLatencyTestAfterGoalSeek -FixedIops $FixedIops

        if ($ioStormMode -ne "FixedIops") {
            New-CSVHeader -CsvPath $csvPath
        }

        if ($FixedIops -ne 0) {
            Log-Info -Message "Will run fixed IO load: $FixedIops IOPS per VM."
            New-CSVHeader -CsvPath $fixedIopsCsvPath
        }

        ##################
        ### VM IOSTORM ###
        ##################
        $diskSpdSummaryResults = @()
        # Start signal for all VMs to start IO pre-sync
        "Start IO pre-sync" | Out-File $ioPreSyncStartSignalFile -Encoding ASCII -Force
        Log-Info -Message "Start IO pre-sync and warm up. ETA: $((Get-Date).AddMinutes(35))."

        if ($RestartRun -eq $true) {
            Get-ChildItem -Path "$ioPreSyncShare\" -Recurse | Remove-Item -Force -ErrorAction Stop
        }

        $ioResultExpectedFiles = $VMCount
        $timeoutInSeconds = 7200
        # Wait for 7200 seconds for IO pre-sync files from all vms to be created
        $noOfRetries = $timeoutInSeconds/60
        $ioPreSyncDidSucceed = $false
        while($noOfRetries -gt 0) {
            Log-Info -Message "Waiting for pre IO workload synchronization and warm up."
            $existingFiles = Get-ChildItem -Path $ioPreSyncShare -ErrorAction SilentlyContinue
            if ($existingFiles.Count -ge $ioResultExpectedFiles) {
                $ioPreSyncDidSucceed = $true
                Log-Info -Message "Pre IO workload synchronization and warm up succeeded."
                break
            }

            Start-Sleep -Seconds 60
            $noOfRetries--
        }

        # Start IO workload by creating sync success/failure file
        if ($ioPreSyncDidSucceed) {
            Log-Info -Message  "Sync Succeeded"
        }
        else {
            Log-Warning -Message "Sync Failed" -Throw
        }

        Log-Info -Message "Azure storage endpoint for output is $outputStorageEndpoint"

        $outputStorageContext = $null
        $outputStorageTable = $null
        $executionId = $($startDate.ToString('yyyyMMdd_HHmm'))
        try {
            $outputStorageContext = New-AzureStorageContext -StorageAccountName $OutputStorageAccountName -StorageAccountKey $outputStorageAccountKey -Endpoint $outputStorageEndpoint -ErrorAction Stop
            if ($outputStorageContext -eq $null) {
                Log-Warning -Message "Azure storage context is null." -Throw
            }
            else {
                Log-Info -Message "Azure storage context creation succeeded."
            }

            $outputStorageTableName = "IoStormResults$($startDate.ToString('MMddHHmm'))"

            # Retrieve the table if it already exists.
            try {
                Log-Info -Message "Checking if storage table $outputStorageTableName already exists"
                $outputStorageTable = Get-AzureStorageTable -Name $outputStorageTableName -Context $outputStorageContext -ErrorAction Stop
                Log-Info -Message "Storage table $outputStorageTableName exists."
            } catch {
                Log-Info -Message "Storage table $outputStorageTableName does not exists. Creating a new table."
            }

            #Create a new table if it does not exist.
            if ($outputStorageTable -eq $null) {
                try {
                    Log-Info -Message "Creating storage table $outputStorageTableName"
                    $outputStorageTable = New-AzureStorageTable -Name $outputStorageTableName -Context $outputStorageContext -ErrorAction Stop
                    Log-Info -Message "Creating storage table $outputStorageTableName succeeded"
                } catch [Exception] {
                    Log-Warning -Message "Storage table $outputStorageTableName cannot be created. $_" -Throw
                }
            }
        }
        catch {
            Log-Warning -Message "Azure storage context cannot be created for a given storage account $OutputStorageAccountName" -Throw
        }


        # Threads equal to Logical Processors inside VM
        # As we stripe data disks to create logical disks, use number of
        # logical disks as the divisor.
        # switch to using logfical disks in thread computation once dependants are altered
        $logicalDisks = 1
        $lps = $vmSizeConfig.NumberOfCores
        if ($IoThreads -eq 0) {
            $threads =[math]::Ceiling($lps / $logicalDisks)
        } else {
            $threads = $IoThreads
        }

        Log-Info -Message "The workload VM has $lps logical processors, $DataDisks data disks. $logicalDisks Logical Disks. Using $threads DiskSpd thread per logical disk."

        $iteration = 0
        try {
            if ($RestartRun -eq $true) {
                #find highest iteration
                $startFilePath = "$smbshare\ioworkloadstart-*"
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
            Log-Warning -Message "Failed to determine start iteration. Defaulting to 0. $_"
        }

        Log-Info -Message "Starting with iteration $iteration :"
        Log-Info -Message "IoBlockSizeInBytes = $IoBlockSizeInBytes"
        Log-Info -Message "IoWritePercentage = $IoBlockSizeInBytes"
        Log-Info -Message "IoDurationInSec = $IoDurationInSec"
        Log-Info -Message "IoRandomIoPercentage = $IoRandomIoPercentage"
        Log-Info -Message "IoRandomIoDistribution = $IoRandomIoDistribution"
        
        $nl = [Environment]::NewLine
        $writePctVal = "WRITEPCT#$IoWritePercentage"
        $blockVal = "BLOCK#$IoBlockSizeInBytes"
        $durationVal = "DURATION#$IoDurationInSec"
        $randomPctVal = "RANDOMPCT#$IoRandomIoPercentage"
        $diskSpdWorkloadPattern = "$writePctVal$nl$blockVal$nl$durationVal$nl$randomPctVal"
        if ($IoRandomIoDistribution) {
            $rdpctVal = "RDPCT#$IoRandomIoDistribution"
            $diskSpdWorkloadPattern += "$nl$rdpctVal"
        }

        # Best Result
        $bestIOPS = -1
        $bestAvg95thLat = $VMIoMaxLatency + 1
        $avg95thLat = 0
        $bestIteration = -1
        $fixedIteration = -1
        # Run IO workload in loop until we reach max latency (using binary search to find QD)
        # Tolerate $latencyFailureCountMax number of latency related failures
        # as the stamp may experience non-test related load from
        # infra at any point in time
        $minQD = $IoMinQueueDepth
        $defaultMaxQD = [math]::Max(512, $IoMinQueueDepth * 100)
        if ($ioStormMode -ne "FixedIops") {
            $maxQD = $defaultMaxQD
        } else {
            $bestQD = $IoMinQueueDepth
            $maxQD = $IoMinQueueDepth
        }

        $latencyFailureCountMax = 3
        $latencyFailureCount = 0
        while ($latencyFailureCount -lt $latencyFailureCountMax -and ($ioStormMode -ne "FixedIops")) {
            if ($latencyFailureCount -eq 0) {
                $qd = [math]::Max(1, [math]::Floor(($minQD + $maxQD) / 2))
            }

            Log-Info -Message "IoStorm mode: $ioStormMode"
            Log-Info -Message "Previous 95th latency: $avg95thLat. Max latency $VMIoMaxLatency"
            Log-Info -Message "Latency failure count: $latencyFailureCount. Max latency failures tolerated: $latencyFailureCountMax"

            # Create IO result share directory for current iteration
            $ioResultIterationShare = $ioResultShare + "\iteration-$iteration"
            New-Item -Path $ioResultIterationShare -Type Directory -Force -Confirm:0 | Out-Null

            # Request VMs to start IO workload with calculated QD and THREAD values e.g. QD:4 \n THREADS:2
            $qdVal = "QD#$qd"
            $threadsVal = "THREADS#$threads"
            $ioWorkloadStartSignalFileIteration = "$ioWorkloadStartSignalFile$iteration"
            Log-Info -Message "Signaling to start IO workload | ITERATION: $iteration QD: $qd THREADS: $threads"
            "$qdVal$nl$threadsVal$nl$diskSpdWorkloadPattern" | Out-File $ioWorkloadStartSignalFileIteration

            # Wait for VM IO workload to finish
            $ioWorkloadDidSucceed = Wait-VMIOWorkload -IoDuration ($IoDurationInSec + 240) -Iteration $iteration -IoResultIterationShare $ioResultIterationShare -IoResultExpectedFiles $ioResultExpectedFiles

            # Parse IO workload results
            # On fixed workload runs this a run may be interupted,
            # so parsing may fail
            try {
                $latencyResult = $null
                if ($ioWorkloadDidSucceed) {
                    $latencyResult = Get-LatencyResult -IoResultIterationShare $ioResultIterationShare -VMIoResultFile $vmioResultFile -StorageTable $outputStorageTable -ExecutionId $executionId -Iteration $iteration -VMCount $VMCount -QueueDepth $qd -NumThreads $threads -RandomIoPercentage $IoRandomIoPercentage -RandomIoDistribution $IoRandomIoDistribution -BlockSize $IoBlockSizeInBytes
                    $diskSpdSummaryResults += $latencyResult
                    $avg95thLat = [float]$latencyResult.summary.Avg95thTotalLat
                } else {
                    "IO workload iteration $iteration result failed." | Out-File $vmioResultFile -Encoding ASCII -Append
                    Log-Warning -Message "IO workload iteration $iteration result failed."
                    break
                }

                # Calculate new values of QD and Thread based on latency value of current run
                if ($latencyResult.summary -ne $null) {
                    $resTxt = Generate-IOSummary -LatencyResult $latencyResult.summary -CsvPath $csvPath -NumThreads $threads -QueueDepth $qd -VMCount $VMCount -Iteration $iteration -ExecutionId $executionId -VMIoResultFile $vmioResultFile -StorageTable $outputStorageTable -DataDisks $DataDisks -RandomIoPercentage $IoRandomIoPercentage

                    # Save best result for either the latest iteration
                    # or for the iteration that has the best iops and within latency max
                    if (($bestIOPS -lt [float]$latencyResult.summary.TotalIops -and $avg95thLat -le $VMIoMaxLatency) -or ($bestAvg95thLat -gt $VMIoMaxLatency)) {
                        $bestIteration = $iteration
                        $bestIOPS = "{0:N0}" -f [float]$LatencyResult.summary.TotalIops
                        $bestAvg95thLat = $avg95thLat
                        $bestQD = $qd
                        $bestResTxt = $resTxt
                    }
                } else {
                    Log-Warning -Message "IO workload iteration $iteration latency result is null. Cannot continue iterations."
                    break
                }
            } catch {
                Log-Warning -Message "Failed to parse results for iteration $_"
            }

            if ($avg95thLat -ge $VMIoMaxLatency) {
                if (([math]::Abs(($avg95thLat - $VMIoMaxLatency)) / $VMIoMaxLatency) -le 0.1) {
                    $latencyFailureCount++
                    $realFailureCount = $latencyFailureCount
                    if (($latencyFailureCount -eq $latencyFailureCountMax) -and ($maxQD -gt $minQD)) {
                        $maxQD = $qd - 1
                        $latencyFailureCount = 0
                    }
                } else {
                    if ($maxQD -le $minQD) {
                        $latencyFailureCount++
                        $realFailureCount = $latencyFailureCount
                    } else {
                        $maxQD = $qd - 1
                        $latencyFailureCount = 0
                        $realFailureCount = 1
                    }
                }

                Log-Info -Message "Latency of $avg95thLat exceeded threshhold of VMIoMaxLatency $VMIoMaxLatency. This has occured $realFailureCount times"
            } else {
                $latencyFailureCount = 0
                if ($minQD -ge $defaultMaxQD) {
                    $minQD = $qd + 2
                } else {
                    $minQD = $qd + 1
                }

                if ($minQD -gt $maxQD) {
                    $maxQD = $minQD
                }
            }

            $iteration += 1
        }

        if ($bestResTxt) {
            Log-Info -Message "GoalSeek iterations are completed."
            # Append best IOPS results of the test run
            "BEST GOAL SEEK IOPS RESULTS:" | Out-File $vmioResultFile -Encoding ASCII -Append
            Log-Info -Message "BEST GOAL SEEK IOPS RESULTS:"
            $bestResTxt | Out-File $vmioResultFile -Encoding ASCII -Append
            Log-Info -Message $bestResTxt
        }

        if (($ioStormMode -eq "GoalSeekFixedIops") -or ($ioStormMode -eq "FixedIops")) {
            Log-Info -Message "Starting fixed IOPS run."
            $ioResultIterationShare = $ioResultShare + "\iteration-$iteration"
            New-Item -Path $ioResultIterationShare -Type Directory -Force -Confirm:0 | Out-Null

            # Request VMs to start IO workload with FIXED IOPS
            $qdVal = "QD#$bestQD"
            $threadsVal = "THREADS#$threads"
            $fixedVal = "FIXED#$FixedIops"
            $ioWorkloadStartSignalFileIteration = "$ioWorkloadStartSignalFile$iteration"
            Log-Info -Message "Signaling to start IO workload | ITERATION: $iteration QD: $bestQD THREADS: $threads FIXED: $FixedIops"
            "$qdVal$nl$threadsVal$nl$fixedVal$nl$diskSpdWorkloadPattern" | Out-File $ioWorkloadStartSignalFileIteration

            # Wait for VM IO workload to finish
            $ioWorkloadDidSucceed = Wait-VMIOWorkload -IoDuration ($IoDurationInSec + 240) -Iteration $iteration -IoResultIterationShare $ioResultIterationShare -IoResultExpectedFiles $ioResultExpectedFiles

            try {
                $latencyResult = $null
                if ($ioWorkloadDidSucceed) {
                    $latencyResult = Get-LatencyResult -IoResultIterationShare $ioResultIterationShare -VMIoResultFile $vmioResultFile -StorageTable $outputStorageTable -ExecutionId $executionId -Iteration $iteration -VMCount $VMCount -QueueDepth $bestQD -NumThreads $threads -RandomIoPercentage $IoRandomIoPercentage -RandomIoDistribution $IoRandomIoDistribution -BlockSize $IoBlockSizeInBytes
                    $diskSpdSummaryResults += $latencyResult
                } else {
                    "IO workload iteration $iteration result failed." | Out-File $vmioResultFile -Encoding ASCII -Append
                    Log-Warning -Message "IO workload iteration $iteration result failed."
                }

                if ($latencyResult.summary -ne $null) {
                    $fixedResTxt = Generate-IOSummary -LatencyResult $latencyResult.summary -CsvPath $fixedIopsCsvPath -NumThreads $threads -QueueDepth $bestQD -VMCount $VMCount -Iteration $iteration -ExecutionId $executionId -VMIoResultFile $vmioResultFile -StorageTable $outputStorageTable -DataDisks $DataDisks -RandomIoPercentage $IoRandomIoPercentage
                    $fixedIteration = $iteration
                } else {
                    Log-Warning -Message "IO workload iteration $iteration latency result is null."
                }
            } catch {
                Log-Warning -Message "Failed to parse results for iteration $_"
            }
        }

        if ($fixedResTxt) {
            Log-Info -Message "Fixed IOPS iteration $fixedIteration is completed."
            # Append fixed IOPS results of the test run
            "FIXED IOPS RESULTS:" | Out-File $vmioResultFile -Encoding ASCII -Append
            Log-Info -Message "FIXED IOPS RESULTS:"
            $fixedResTxt | Out-File $vmioResultFile -Encoding ASCII -Append
            Log-Info -Message $fixedResTxt
        }

        Generate-HtmlSummary -ResultSummary $diskSpdSummaryResults -FilePath $resultHtmlPath -BestIteration $bestIteration -FixedIteration $fixedIteration

        $outputStorageContainerName = "iostormresults$($startDate.ToString('MMddHHmm'))"

        try {
            if ((Get-AzureStorageContainer -Name $outputStorageContainerName -Context $outputStorageContext -ErrorAction SilentlyContinue) -ne $null) {
                Log-Info -Message "Removing existing storage container $outputStorageContainerName"
                Remove-AzureStorageContainer -Name $outputStorageContainerName -Context $outputStorageContext -PassThru -Force -Confirm:0 -ErrorAction Stop | Out-Null
                Start-Sleep -Seconds 30
            }

            New-AzureStorageContainer -Name $outputStorageContainerName -Context $outputStorageContext -Permission Blob -ErrorAction Stop | Out-Null

            # Upload iostorm results to azure storage blob
            Log-Info -Message "Uploading IO workload results $vmioResultFile to Azure storage account $OutputStorageAccountName in resource group $OutputResourceGroup"
            Set-AzureStorageBlobContent -File $vmioResultFile -Context $outputStorageContext -Container $outputStorageContainerName -Force -ErrorAction Stop | Out-Null

            #upload summary html
            Log-Info -Message "Uploading Test Result Summary $resultHtmlPath to Azure storage account $OutputStorageAccountName in resource group $OutputResourceGroup"
            Set-AzureStorageBlobContent -File $resultHtmlPath -Context $outputStorageContext -Container $outputStorageContainerName -Force -ErrorAction Stop | Out-Null
    
            # Upload iostorm execution logs to azure storage blob
            Log-Info -Message "Uploading IO workload execution logs $logFilePath to Azure storage account $OutputStorageAccountName in resource group $OutputResourceGroup"
            $logTempPath = "$env:TEMP\$logFileName"
            Copy-Item -Path $logFilePath -Destination $logTempPath -Force -ErrorAction Stop
            Set-AzureStorageBlobContent -File $logTempPath -Context $outputStorageContext -Container $outputStorageContainerName -Force -ErrorAction Stop | Out-Null
        } catch [Exception] {
            Log-Warning -Message "Uploading log and results to Azure Storage Blob failed with exception $_"
        }

        "IoStorm test finished." | Tee-Object -FilePath $statusFilePath -Append
        if ($bestResTxt) {
            "Best Goal Seek Iteration: $bestResTxt" | Tee-Object -FilePath $statusFilePath -Append
        }

        if ($fixedResTxt) {
            "Fixed IOPS Iteration: $fixedResTxt" | Tee-Object -FilePath $statusFilePath -Append
        }
    } catch {
        Log-Warning "IoStorm test failed: $_"
        throw
    } finally {
        if ($smbshare) {
            Copy-Item -Path $smbshare\ -Destination $localPath\Logs -Force -Recurse -ErrorAction SilentlyContinue
            try { net use /delete $smbshare | Out-Null } catch { Log-Warning -Message "Failed to remove network path: $_" }
        }

        if (-not $SkipCleanUp) {
            if (Get-AzureRmResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue) {
                Log-Info -Message "Removing resource group $ResourceGroup"
                Remove-AzureRmResourceGroup -Name $ResourceGroup -Force -Verbose -ErrorAction SilentlyContinue | Out-Null
            }
        }

        Stop-Transcript -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function Start-IoStorm

# SIG # Begin signature block
# MIIjewYJKoZIhvcNAQcCoIIjbDCCI2gCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAW9R9mkY1eXQEb
# zEpxvmn41xA7EABZyml7fpDhqPH6SqCCDXYwggX0MIID3KADAgECAhMzAAAB3vl+
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
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEICdRfgK/EALpTl6eqOa81MDQ
# hf2jph3dlOl/FUr/w58oMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAdP9I5MvyWtKNn7umV+qo7BZbT/H9FP7QIMkUTtMygmdke7VOD+G88AUE
# 4DQS7xyOeoKmNLAa1SH9VYY9zgOz8kIQn9IQFVZHvIKhG71FMxAijidStZqpeJ+U
# 8JO8PKhWcISlC/6S1pcQom62apYwx7qFEs1ex1xVqikDIvKULYpJVyjJzjrktgt/
# r8KY99wLp16N5qARRq7R8UZGczCR/jt1oO4JWsHuyycw38PCDuuDtyMQV0hVjea0
# UxEp1UNuyUUUTG9uWcQnJCk8axDbH0QKYR/JeKgECO4bigw7AW1keE1KGb5A0ctY
# jGHs4dcvZW++iLdLU6kY77wIg6s1JqGCEuUwghLhBgorBgEEAYI3AwMBMYIS0TCC
# Es0GCSqGSIb3DQEHAqCCEr4wghK6AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFRBgsq
# hkiG9w0BCRABBKCCAUAEggE8MIIBOAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCDPirm+ETeB4ADIbgTMFSWwnD1AKBIVT0VBqGu7ig3ghgIGYUObsGZi
# GBMyMDIxMDkyNjA3MDE0MS44NzlaMASAAgH0oIHQpIHNMIHKMQswCQYDVQQGEwJV
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
# DQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIK81yeNaU+dioOajQSD/ybxM
# C2NcB1m5xEOYkF1UkGD9MIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgbB2S
# 162521f+Sftir8BViIFZkGr6fgQVVDzNQPciUQMwgZgwgYCkfjB8MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAUqk9zHE/yKiSQAAAAABSjAiBCCO0jOx
# BjcTj2Bj+BZBRZYqZeEL1alkHUnGaI1+a/fvhTANBgkqhkiG9w0BAQsFAASCAQBb
# n4pVJYCo3HAwByKYe59P4Mmh48tBx3pTyrbH8oxj6y8mtlZ1M8Z2oofHVR6AsJhz
# okXke6XJsaMU7ZxIZT66rna84cNlRyIepeALQooXrZqYNEG0CkX47HHeAssgFWB+
# RKYc5bE+Vufx6SoA/FCUyzWE7rsCi9qbF3m2fnkwabB5KXZFBjht10uYVcyItfDQ
# KJ+NDQxd8QAXPf166LIKI/twiOKvHINFrS1kPcpks7sUqw7qJKUxxp0BzYqZlY6K
# JmbG1sXy6MyK1L79S+30+4e7U8f78zCKqhBX4WchGfXmX8I/xRe9hK6W+mjcikip
# krFKyoVgujl9ylS0ssvh
# SIG # End signature block
