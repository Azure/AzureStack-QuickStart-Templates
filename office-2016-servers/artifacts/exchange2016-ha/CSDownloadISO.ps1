param (
	[Parameter(Mandatory)]
    [string]$uri,
	[Parameter(Mandatory)]
    [string]$destination,
    [Parameter(Mandatory)]
	[string]$urlMSFTAST,
	[Parameter(Mandatory)]
	[string]$urlUCMA4,
	[Parameter(Mandatory)]
	[string]$urlVcredist,
	[Parameter(Mandatory)]
	[string]$urlNDP471
)

function DownloadISO {

	# Local file storage location
	$localPath = "$env:SystemDrive"
	#Array of allowed exchange versions (starting from CU8)
    $exallowedlist = "15.1.1415.2","15.1.1466.3","15.1.1531.3"
    # Log file
    $logFileName = "CSDownload.log"
	$logFilePath = "$localPath\$logFileName"
	$returnBuild = ''
	
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
		
		#Check if version is allowed
		$SetupFile = Join-Path $driveLetter "Setup.exe"
		$FileVersion = Get-Command $SetupFile | ForEach{$_.FileVersionInfo}
		if ($exallowedlist -match $FileVersion.ProductVersion)
		{
		   "Exchange 2016 installer in compatibility range"
		   $returnBuild = $FileVersion.ProductVersion
		}
		else
		{
			Throw "Exchange 2016 build  "+$FileVersion.ProductVersion+" not allowed"
		}

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
	
	return $returnBuild
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

function DownloadInstallUCMA4 {
	$destination = "MSFT_UCMA4"
    $destination = Join-Path $env:SystemDrive $destination
    if(-not (Test-Path $destination)) {
		New-Item -Path $destination -ItemType directory -Force
	}
    $output = "$destination\UcmaRuntimeSetup.exe"
    if (-not (Test-Path $output)) {
        cd "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy"
        .\AzCopy.exe /Source:$urlUCMA4 /Dest:$output
        cd $destination
        .\UcmaRuntimeSetup.exe /q
	}
	else
	{
		Throw "Error in downloading UCMA4 installer"
	}
}

function DownloadInstallVcredist($BuildNumber)  {
	if ($BuildNumber -eq "15.1.1531.3"){
	$destination = "vcredist"
    $destination = Join-Path $env:SystemDrive $destination
    if(-not (Test-Path $destination)) {
		New-Item -Path $destination -ItemType directory -Force
	}
    $output = "$destination\vcredist_x64.exe"
    if (-not (Test-Path $output)) {
        cd "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy"
        .\AzCopy.exe /Source:$urlVcredist /Dest:$output
        cd $destination
        .\vcredist_x64.exe /q
	}
	else
	{
		Throw "Error in downloading vcredist installer"
	}
}
}

function DownloadInstallNDP471($BuildNumber) {
	if ($BuildNumber -eq "15.1.1531.3"){
	$destination = "ndp471"
    $destination = Join-Path $env:SystemDrive $destination
    if(-not (Test-Path $destination)) {
		New-Item -Path $destination -ItemType directory -Force
	}
    $output = "$destination\NDP471-KB4033342-x86-x64-AllOS-ENU.exe"
    if (-not (Test-Path $output)) {
        cd "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy"
        .\AzCopy.exe /Source:$urlNDP471 /Dest:$output
        cd $destination
        .\NDP471-KB4033342-x86-x64-AllOS-ENU.exe /q
	}
	else
	{
		Throw "Error in downloading .net framework 4.7.1 installer"
	}
}
}

DownloadInstallAZCopy
$buildNumber = DownloadISO
DownloadInstallUCMA4
DownloadInstallVcredist $buildNumber
DownloadInstallNDP471 $buildNumber