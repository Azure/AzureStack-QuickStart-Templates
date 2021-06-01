param (
	[Parameter(Mandatory)]
    [string]$uri,
	[Parameter(Mandatory)]
    [string]$destination
)

function DownloadISO {

	filter timestamp {"$(Get-Date -Format "yyyy-MM-dd HH:mm:ss.ffff") $_"}
	# Local file storage location
    $localPath = "$env:SystemDrive"

    # Log file
    $logFileName = "CSDownload.log"
    $logFilePath = "$localPath\$logFileName"
	
	if(Test-Path $destination) {
		"$(timestamp) Destination path exists. Skipping ISO download" | Tee-Object -FilePath $logFilePath -Append
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
			"$(timestamp) Downloading URI: $uri ($sizeInBytes bytes) to path: $destination" | Tee-Object -FilePath $logFilePath -Append
			$isoFileName = [System.IO.Path]::GetFileName($uri)
			$webClient = New-Object System.Net.WebClient
			$_date = Get-Date -Format hh:mmtt
			$destinationFile = "$destination\$isoFileName"
			$webClient.DownloadFile($uri, $destinationFile)
			$_date = Get-Date -Format hh:mmtt
			if((Test-Path $destinationFile) -eq $true) {
				"$(timestamp) Downloading ISO file succeeded at $_date" | Tee-Object -FilePath $logFilePath -Append
				$result = $true
			}
			else {
				"$(timestamp) Downloading ISO file failed at $_date" | Tee-Object -FilePath $logFilePath -Append
				$result = $false
			}
		} catch [Exception] {
			"$(timestamp) Failed to download ISO. Exception: $_" | Tee-Object -FilePath $logFilePath -Append
			$retries--
			if($retries -eq 0) {
				Remove-Item $destination -Force -Confirm:0 -ErrorAction SilentlyContinue
			}
		}
		
	}
	
	# Extract ISO
	if($result)
    {
        "$(timestamp) Mount the image from $destinationFile" | Tee-Object -FilePath $logFilePath -Append
        $image = Mount-DiskImage -ImagePath $destinationFile -PassThru
		$driveLetter = ($image | Get-Volume).DriveLetter
		"$(timestamp) Setting the mounted ISO image drive letter to J" | Tee-Object -FilePath $logFilePath -Append
		$drive = Get-WmiObject -Class win32_volume -Filter "DriveLetter = '$($driveLetter):'"
		Set-WmiInstance -input $drive -Arguments @{DriveLetter="J:"}
		"$(timestamp) Successfully set the mounted ISO image drive letter to J" | Tee-Object -FilePath $logFilePath -Append
		
        "$(timestamp) Copy files to destination directory: $destination" | Tee-Object -FilePath $logFilePath -Append
		#Robocopy.exe ("{0}:" -f $driveLetter) $destination /E | Out-Null
		Robocopy.exe J:\Setup\ServerRoles\Common\perf\amd64 "$destination\Setup\ServerRoles\Common\perf\amd64" eseperf*
		Robocopy.exe J:\Setup\ServerRoles\Common "$destination\Setup\ServerRoles\Common" ese.dll
    
        "$(timestamp) Dismount the image from $destinationFile" | Tee-Object -FilePath $logFilePath -Append
        Dismount-DiskImage -ImagePath $destinationFile
    
        "$(timestamp) Delete the temp file: $destinationFile" | Tee-Object -FilePath $logFilePath -Append
		Remove-Item -Path $destinationFile -Force
		
    }
    else
    {
		"$(timestamp) Failed to download the file after exhaust retry limit" | Tee-Object -FilePath $logFilePath -Append
		Remove-Item $destination -Force -Confirm:0 -ErrorAction SilentlyContinue
        Throw "Failed to download the file after exhaust retry limit"
    }
}

DownloadISO