param (
	[Parameter(Mandatory)]
    [string]$uri,
	[Parameter(Mandatory)]
    [string]$destination,
    [Parameter(Mandatory)]
	[string]$baseUrl,
    [Parameter(Mandatory)]
	[string]$urlMSFTAST,
	[Parameter(Mandatory)]
	[string]$prereqList,
	[Parameter(Mandatory)]
	[string]$patchName,
	[Parameter(Mandatory)]
	[string]$langPatchName
)

function DownloadISO {

	# Local file storage location
	$localPath = "$env:SystemDrive"
    # Log file
    $logFileName = "CSDownload.log"
    $logFilePath = "$localPath\$logFileName"

	if(Test-Path $destination) {
		"Destination path exists. Skipping ISO download" | Tee-Object -FilePath $logFilePath -Append
		return
	}
	
	$destination = Join-Path $env:SystemDrive $destination
	New-Item -Path $destination -ItemType Directory

	$destinationFile = $null
    $result = $false
	# Download ISO
	$retries = 3
	# Stop retrying after download succeeds or all retries attempted
	while(($retries -gt 0) -and ($result -eq $false)) {
		try
		{
			"Downloading ISO from URI: $uri to destination: $destination" | Tee-Object -FilePath $logFilePath -Append
			$isoFileName = [System.IO.Path]::GetFileName($uri)
			#$webClient = New-Object System.Net.WebClient
			$_date = Get-Date -Format hh:mmtt
			$destinationFile = "$destination\$isoFileName"
			cd "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy"
            .\AzCopy.exe /Source:$uri /Dest:$destinationFile
			#$webClient.DownloadFile($uri, $destinationFile)
			$_date = Get-Date -Format hh:mmtt
			if((Test-Path $destinationFile) -eq $true) {
				"Downloading ISO file succeeded at $_date" | Tee-Object -FilePath $logFilePath -Append
				$result = $true
			}
			else {
				"Downloading ISO file failed at $_date" | Tee-Object -FilePath $logFilePath -Append
				$result = $false
			}
		} catch [Exception] {
			"Failed to download ISO. Exception: $_" | Tee-Object -FilePath $logFilePath -Append
			$retries--
			if($retries -eq 0) {
				Remove-Item $destination -Force -Confirm:0 -ErrorAction SilentlyContinue
			}
		}
	}
	
	# Extract ISO
	if($result)
    {
        "Mount the image from $destinationFile" | Tee-Object -FilePath $logFilePath -Append
        $image = Mount-DiskImage -ImagePath $destinationFile -PassThru
		$driveLetter = ($image | Get-Volume).DriveLetter

        "Copy files to destination directory: $destination" | Tee-Object -FilePath $logFilePath -Append
        Robocopy.exe ("{0}:" -f $driveLetter) $destination /E | Out-Null
    
        "Dismount the image from $destinationFile" | Tee-Object -FilePath $logFilePath -Append
        Dismount-DiskImage -ImagePath $destinationFile
    
        "Delete the temp file: $destinationFile" | Tee-Object -FilePath $logFilePath -Append
        Remove-Item -Path $destinationFile -Force
    }
    else
    {
		"Failed to download the file after exhaust retry limit" | Tee-Object -FilePath $logFilePath -Append
		Remove-Item $destination -Force -Confirm:0 -ErrorAction SilentlyContinue
        Throw "Failed to download the file after exhaust retry limit"
    }
}

function DownloadInstallAZCopy {

    $destination = "MSFT_AzureStorageTools"
    $destination = Join-Path $env:SystemDrive $destination
    if(-not (Test-Path $destination)) {
		New-Item -Path $destination -ItemType directory -Force
	}
    $output = "$destination\MicrosoftAzureStorageTools.msi"
    if (-not (Test-Path $output)) {
		Invoke-WebRequest -Uri $urlMSFTAST -OutFile $output
        cd $destination
        Start-Process C:\Windows\System32\msiexec.exe -ArgumentList "/package MicrosoftAzureStorageTools.msi /quiet" -wait
	}

    if(Test-Path "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy") {
        Write-Verbose "Ok"
	}
	else
	{
		Throw "Aborting, Azure Storage Tools not installed correctly"
	}
}

function DownLoadPrereq {
	$destination="prereqSp2016"
	$arrayList = $prereqList.split(",")
	$destination = Join-Path $env:SystemDrive $destination 
    if(-not (Test-Path $destination)) {
		New-Item -Path $destination -ItemType directory -Force
	}
	Foreach ($fileName in $arrayList)
	{
		$output = "$destination\$fileName"
		$urlToDownload = $baseUrl+"/"+$fileName
		if (-not (Test-Path $output)) {
			cd "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy"
			.\AzCopy.exe /Source:$urlToDownload /Dest:$output
		}
		else
		{
			Throw "Error in downloading $filename sharepoint prerequisite"
		}
	}
}

function SlipstreamPatch {
	$patchExe = Join-Path (Join-Path $env:SystemDrive "prereqSp2016") $patchName
	$langPatchExe = Join-Path (Join-Path $env:SystemDrive "prereqSp2016") $langPatchName
	$updatesFolder = Join-Path (Join-Path $env:SystemDrive $destination) "updates"
	Start-Process $patchExe -ArgumentList "/extract:$updatesFolder /quiet" -wait
	Start-Process $langPatchExe -ArgumentList "/extract:$updatesFolder /quiet" -wait
}

DownloadInstallAZCopy
DownloadISO
DownLoadPrereq
SlipstreamPatch
