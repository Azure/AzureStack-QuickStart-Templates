#
# Copyright="Microsoft Corporation. All rights reserved."
#

# Local file storage Location
$localPath = "$env:SystemDrive"

# Log file
$logFileName = "InstallVMWorkloadController.log"
$logFilePath = "$localPath\$logFileName"
Start-Transcript -Path $logFilePath -Append -Force -ErrorAction SilentlyContinue

netsh advfirewall set privateprofile state off

# Create a scheduled task to execute controller script asynchronously
$psScriptName = "VMIOControllerTask.ps1"
Copy-Item -Path ".\$psScriptName" -Destination "$localPath\$psScriptName" -Force -Verbose

$action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument "-NoLogo -NoProfile -ExecutionPolicy Unrestricted -WindowStyle Hidden -File $localPath\$psScriptName -Verbose"

$trigger = @()
$trigger += New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
$trigger += New-ScheduledTaskTrigger -AtStartup


$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 240) -ErrorAction Ignore
Unregister-ScheduledTask -TaskName "VMIOController" -Confirm:0 -ErrorAction Ignore
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "VMIOController" -Description "VM iostorm" -User "System" -RunLevel Highest -Settings $settings

Write-Host "ScheduledTask VMIOController has been registered."

Stop-Transcript -ErrorAction SilentlyContinue
