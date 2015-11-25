$rgName = "myRG001"
$vmName = "myVM001"
$extName = "VMAccess"

#Get VMAccessAgent Extension Info (throws error if notexists)
Get-AzureRmVMAccessExtension -ResourceGroupName $rgName -VMName $vmName -Name $extName

# Set VMAccessAgent Extension (Reset Password)
Set-AzureRmVMAccessExtension -ResourceGroupName $rgName -VMName $vmName -Name $extName -UserName "admin" -Password "User@123" -Location "Local"

# Remove VMAccessAgent Extension
Remove-AzureRmVMAccessExtension -ResourceGroupName $rgName -VMName $vmName -Name $extName