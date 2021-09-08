#
# Copyright="Microsoft Corporation. All rights reserved."
#

# Log file
$logFileName = "CreateVMWorkloadControllerShare.log"
$logFilePath = "$env:SystemDrive\$logFileName"
Start-Transcript -Path $logFilePath -Append -Force -ErrorAction SilentlyContinue

function Create-VMIOControllerShare {
    # Turn off private firewall
    Set-NetFirewallProfile -Enabled:0 -Confirm:0

    # Create result SMB share
    $smbshare = "$env:SystemDrive\smbshare"
    if((Get-Item -Path $smbshare -ErrorAction SilentlyContinue) -eq $null) {
        Log-Info -Message "Creating result smb share $smbshare"
        New-Item -Path $smbshare -Type Directory -Force -Confirm:0
    }

    if((Get-SMBShare -Name smbshare -ErrorAction SilentlyContinue) -eq $null) {
        New-SMBShare -Path $smbshare -Name smbshare -FullAccess Everyone
    }

    # Create IO workload pre-sync directory
    $ioPreSyncShare = "$smbshare\iopresync"
    if((Get-Item -Path $ioPreSyncShare -ErrorAction SilentlyContinue) -eq $null) {
        Log-Info -Message "Creating IO pre-sync share $ioPreSyncShare"
        New-Item -Path $ioPreSyncShare -Type Directory -Force -Confirm:0
    }

    # Create Log directory
    $logShare = "$smbshare\logs"
    if((Get-Item -Path $logShare -ErrorAction SilentlyContinue) -eq $null) {
        Log-Info -Message "Creating logs share $logShare"
        New-Item -Path $logShare -Type Directory -Force -Confirm:0
    }

    # Create IO result directory
    $ioResultShare = "$smbshare\ioresult"
    if((Get-Item -Path $ioResultShare -ErrorAction SilentlyContinue) -eq $null) {
        Log-Info -Message "Creating IO result share $ioResultShare"
        New-Item -Path $ioResultShare -Type Directory -Force -Confirm:0
    }

    Log-Info "The IO controller shares have been successfully created."
}

function Log-Info
{
    param (
        [string]$Message
    )

    $str = "$(Get-Date) $Message"
    Write-Host $str
}

Create-VMIOControllerShare
Stop-Transcript -ErrorAction SilentlyContinue