param (
    [String]$resourceGroupName,
    [String]$adminPassword
)
Write-Output "Starting Reboot and Reimage Integration Tests"

# Output the current PowerShell Version for informational purposes
Write-Output "PowerShell Version Installed"
$PSVersionTable.PSVersion
Write-Output ""

################################################
# Get Deployment information
################################################

# Get the name of the VMSS from Deployment "vmss-dep-reg1"
$vmssDeploymentRegion1Name = "vmss-dep-reg1"
$vmssDeploymentOutputs = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $vmssDeploymentRegion1Name).Outputs
$vmssName = ($vmssDeploymentOutputs["result"].Value.ToString() | ConvertFrom-Json).name
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Restart instance #1 of the VM Scale Set
Write-Host "Restarting $vmssName node 1"
az vmss restart --resource-group $resourceGroupName --name $vmssName --instance-id 1
Write-Host "Restarted $vmssName node 1"
Write-Host "Sleeping for 90 Seconds"
Start-Sleep 90
Write-Host "Starting Integration Tests after restart"
. ("$ScriptDirectory\IntegrationTests.ps1") -resourceGroupName $resourceGroupName -adminPassword $adminPassword

# Reimage instance #1 of the VM Scale Set
Write-Host "Reimaging $vmssName node 1"
az vmss reimage --resource-group $resourceGroupName --name $vmssName --instance-id 1
Write-Host "Reimaged $vmssName node 1"
Write-Host "Sleeping for 90 Seconds"
Start-Sleep 90
Write-Host "Starting Integration Tests after reimage"
. ("$ScriptDirectory\IntegrationTests.ps1") -resourceGroupName $resourceGroupName -adminPassword $adminPassword

# Finish
Write-Output "Finished Reboot and Reimage Integration Tests"