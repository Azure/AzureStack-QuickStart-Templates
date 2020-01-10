###########################
# Install & configure WSUS
###########################

Param (
[string] $SyncHours,
[string] $SyncMinutes 
)


#Initializing data disk
$newdisk = Get-Disk | where partitionstyle -eq 'raw'
$dl = get-Disk $newdisk.Number | Initialize-Disk -PartitionStyle MBR -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize 
Format-Volume -DriveLetter $dl.Driveletter -FileSystem NTFS -NewFileSystemLabel "WSUS" -Confirm:$false -Force

#Creating a new folder named WsusContent in the new disk
New-Item -Path $dl.Driveletter -Name WsusContent -ItemType Directory

#Installing WSUS Role (we are using WID)
Install-WindowsFeature -Name UpdateServices -IncludeManagementTools

#navigating to the location where we have WSUS utility installed
cd 'C:\Program Files\Update Services\Tools'

#executing WSUS post installation steps
.\wsusutil.exe postinstall CONTENT_DIR=F:\WsusContent

#Get WSUS Server Object
$wsus = Get-WSUSServer
 
#Connect to WSUS server configuration
$wsusConfig = $wsus.GetConfiguration()
 
#Set to download updates from Microsoft Updates
$null = Set-WsusServerSynchronization -SyncFromMU
 
#Set Update Languages to English and save configuration settings
$wsusConfig.AllUpdateLanguagesEnabled = $false
$wsusConfig.SetEnabledUpdateLanguages("en")
$wsusConfig.Save()

#Configuring the Classifications
write-Output 'Setting WSUS Classifications'
Get-WsusClassification | Set-WsusClassification -Disable
Get-WsusClassification | Where-Object {
    $_.Classification.Title -in (
    'Critical Updates',`
    'Definition Updates',`
    'Security Updates',`
    'Service Packs',`
    'Update Rollups',`
    'Updates'
)
} | Set-WsusClassification


#Disabling all products
Write-Output 'Disable all products'
Get-WsusProduct | Set-WSUSProduct -Disable


#Get WSUS Subscription and perform initial synchronization to get latest categories
$subscription = $wsus.GetSubscription()
$subscription.StartSynchronizationForCategoryOnly()

Write-Output 'Beginning first WSUS Sync to get available Products etc'

While ($subscription.GetSynchronizationStatus() -ne 'NotProcessing') {
   Write-Output "." -NoNewline
    Start-Sleep -Seconds 5
}
write-Output ' '
Write-Output "Sync is done."

#Configuring the product categories from which we want WSUS updates
write-Output 'Setting WSUS Products'
Get-WsusProduct | where-Object {
    $_.Product.Title -in (
'Windows Server 2019',
'Windows Server 2016'
)
} | Set-WsusProduct


#Configuring Synchronizations
write-Output 'Enabling WSUS Automatic Synchronisation'
$subscription.SynchronizeAutomatically=$true
 
#Setting synchronization schedule
$subscription.SynchronizeAutomaticallyTimeOfDay= (New-TimeSpan -Hours $SyncHours -Minutes $SyncMinutes)
$subscription.NumberOfSynchronizationsPerDay=4
$subscription.Save()


#Creating Computer Groups
$GroupName ="Azs"
$wsus.CreateComputerTargetGroup($GroupName)

#Setting Client side targeting
$wsusConfig.TargetingMode = "Client"
$wsusConfig.Save($false)


#Configuring Default Approval Rule 
[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
$rule = $wsus.GetInstallApprovalRules() | Where {
    $_.Name -eq "Default Automatic Approval Rule"}
$class = $wsus.GetUpdateClassifications() | ? {$_.Title -In (
    'Critical Updates',
    'Definition Updates',
    'Security Updates',
    'Service Packs',
    'Update Rollups',
    'Updates')}
$class_coll = New-Object Microsoft.UpdateServices.Administration.UpdateClassificationCollection
$class_coll.AddRange($class)
$rule.SetUpdateClassifications($class_coll)
$rule.Enabled = $True
$rule.Save()

#Runing Default Approval Rule
try {
$Apply = $rule.ApplyRule()
}
catch {
write-warning $_
}
Finally {
write-Output 'WSUS log files can be found here: %ProgramFiles%\Update Services\LogFiles'
write-Output 'Done!' 
}

#Starting the synchronization
$subscription.StartSynchronization()