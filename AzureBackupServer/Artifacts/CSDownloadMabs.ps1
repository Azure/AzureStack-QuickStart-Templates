param (
	[Parameter(Mandatory)]
    [string]$destination,
    [Parameter(Mandatory)]
	[string]$baseUrl,
    [Parameter(Mandatory)]
	[string]$urlMSFTAST,
	[Parameter(Mandatory)]
	[string]$prereqList,
	[Parameter(Mandatory)]
	[string]$vaultName
)


function DownloadInstallAZCopy {

    $dest = "MSFT_AzureStorageTools"
    $dest = Join-Path $env:SystemDrive $destination
    if(-not (Test-Path $dest)) {
		New-Item -Path $dest -ItemType directory -Force
	}
    $output = "$dest\MicrosoftAzureStorageTools.msi"
    if (-not (Test-Path $output)) {
		Invoke-WebRequest -Uri $urlMSFTAST -OutFile $output
        cd $dest
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
	$arrayList = $prereqList.split(",")
	$dest = Join-Path $env:SystemDrive $destination 
    if(-not (Test-Path $dest)) {
		New-Item -Path $dest -ItemType directory -Force
	}
	Foreach ($fileName in $arrayList)
	{
		$output = "$dest\$fileName"
		$urlToDownload = $baseUrl+"/"+$fileName
		if (-not (Test-Path $output)) {
			cd "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy"
			.\AzCopy.exe /Source:$urlToDownload /Dest:$output
		}
		else
		{
			Throw "Error in downloading $filename mabs prerequisite"
		}
	}
}

function DownloadVault {
	$vaultUrl = $baseUrl+ "/" + $vaultName
	$vaultPath = "c:\vaultProfile"
	$vaultLocalPath = Join-Path $vaultPath $vaultName
	if (-not (Test-Path $vaultPath)) {
		New-Item -Path $vaultPath -ItemType directory -Force
	}
	cd "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy"
	.\AzCopy.exe /Source:$vaultUrl /Dest:$vaultLocalPath
}

function InstallPrereqs {
	$dest = Join-Path (Join-Path $env:SystemDrive $destination) "System_Center_Microsoft_Azure_Backup_Server_v3.exe"
    if(Test-Path $dest) {
		Start-Process $dest -ArgumentList "/verysilent /dir=c:\MABS" -wait 
	}
}

function HypervInstall {
	Start-Process "dism.exe" -ArgumentList "/Online /Enable-feature /All /FeatureName:Microsoft-Hyper-V /FeatureName:Microsoft-Hyper-V-Management-PowerShell /quiet /norestart" -wait
}


DownloadInstallAZCopy
DownLoadPrereq
InstallPrereqs
DownloadVault
HypervInstall

