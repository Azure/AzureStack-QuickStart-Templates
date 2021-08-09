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
    [int]$DataDiskSizeGB
)

# Local file storage Location
$localPath = "$env:SystemDrive"

# Log file
$logFileName = "InstallVMWorkload.log"
$logFilePath = "$localPath\$logFileName"
Start-Transcript -Path $logFilePath -Append -Force -ErrorAction SilentlyContinue

netsh advfirewall set privateprofile state off

$psScriptName = "VMIOWorkloadTask.ps1"
Copy-Item -Path ".\$psScriptName" -Destination "$localPath\$psScriptName" -Force -Verbose

$diskSpdName = "diskspd.exe"
Copy-Item -Path ".\$diskSpdName" -Destination "$localPath\$diskSpdName" -Force -Verbose

# Create a scheduled task to execute controller script asynchronously
$action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument "-NoLogo -NoProfile -ExecutionPolicy Unrestricted -WindowStyle Hidden -File $localPath\$psScriptName -ControllerVMName $ControllerVMName -ControllerVMPrivateIP $ControllerVMPrivateIP -VMName $VMName -VMAdminUserName $VMAdminUserName -VMAdminPassword $VMAdminPassword -DataDisks $DataDisks -DataDiskSizeGB $DataDiskSizeGB -Verbose"

$trigger = @()
$trigger += New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2)
if($FixedIops -ne 0) {
    $trigger += New-ScheduledTaskTrigger -AtStartup
}

$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 240) -Priority 4 -ErrorAction Ignore
Unregister-ScheduledTask -TaskName "VMIOWorkload" -Confirm:0 -ErrorAction Ignore
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "VMIOWorkload" -Description "VM iostorm" -User "System" -RunLevel Highest -Settings $settings

Stop-Transcript -ErrorAction SilentlyContinue
