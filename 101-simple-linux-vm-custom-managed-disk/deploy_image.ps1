
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({
        if(-Not ($_ | Test-Path) ){
            throw "File or folder does not exist"
        }
        if(-Not ($_ | Test-Path -PathType Leaf) ){
            throw "The Path argument must be a file. Folder paths are not allowed."
        }
        if($_ -notmatch "(\.vhd)"){
            throw "The file specified in the path argument must be of type 'vhd'"
        }
        return $true 
    })]
    [System.IO.FileInfo]
    $Image,
    $resourceGroup = "image_test",
    $ImageName,
    [Parameter(Mandatory = $true)]
    [ValidateScript({
        if(-Not ($_ | Test-Path) ){
            throw "File or folder does not exist"
        }
        if(-Not ($_ | Test-Path -PathType Leaf) ){
            throw "The Path argument must be a file. Folder paths are not allowed."
        }
        if($_ -notmatch "(\.pub)"){
            throw "The file specified in the path argument must be of type 'vhd'"
        }
        return $true 
    })]
    [System.IO.FileInfo]
    $sshKeyFile,
    $blobbaseuri = "local.azurestack.external",
    $location = "local",
    $adminUsername = "ubuntu",
    $VMName = "linuxvm1",
    $ImageStorageAccount = "images",
    $ImageRG = "images",
    [switch]$testOnly

)

$ImageContainername = "vhds"
$sshKey = Get-Content $sshKeyFile
if (!$ImageName){
    $ImageName = (Split-Path -Leaf $Image) -replace ".vhd"
}

$storageType = 'Standard_LRS'

Write-Host "==>Creating ResourceGroups $resourceGroup" -nonewline   
New-AzureRmResourceGroup -Name $resourceGroup -Location $location -Force -ErrorAction SilentlyContinue | out-null    
Write-Host -ForegroundColor green "[done]"
$account_available = Get-AzureRmStorageAccountNameAvailability -Name $ImageStorageAccount -ErrorAction SilentlyContinue 
$account_free = $account_available.NameAvailable
if ($account_free -eq $true) {
    try {
        Write-Host -ForegroundColor White -NoNewline "Checking for RG $ImageRG "
        $RG = Get-AzureRmResourceGroup -Name $ImageRG -Location local -ErrorAction Stop  
    }
    catch {
        Write-Host -ForegroundColor yellow [need to create]
        Write-Host -ForegroundColor White -NoNewline "Creating Image RG $ImageRG"        
        $RG = New-AzureRmResourceGroup -Name $ImageRG -Location $location
        Write-Host -ForegroundColor Green [Done]
    }
    $newAcsaccount = New-AzureRmStorageAccount -ResourceGroupName $ImageRG `
        -Name $ImageStorageAccount -Location $location `
        -Type $storageType # -ErrorAction SilentlyContinue
    if (!$newAcsaccount) {
        $newAcsaccount = Get-AzureRmStorageAccount -ResourceGroupName $ImageRG | Where-Object StorageAccountName -match $ImageStorageAccount
    }    
    $newAcsaccount | Set-AzureRmCurrentStorageAccount
    Write-Host "Creating Container `"$ImageContainername`" in $($newAcsaccount.StorageAccountName)"
    New-AzureStorageContainer -Name $ImageContainername -Permission blob | out-null
}
else {
    Write-Host "$ImageStorageAccount already exists, operations might fail if not owner in same location" 
} 

$ImageVHD = Split-Path -Leaf $Image
$urlOfUploadedImageVhd = ('https://' + $ImageStorageAccount + '.blob.' + $blobbaseuri + '/' + $ImageContainername + '/' + $ImageVHD)
Write-Host "Starting upload Procedure for $ImageVHD into storageaccount $ImageStorageAccount, this may take a while"
try {
    Add-AzureRmVhd -ResourceGroupName $ImageRG -Destination $urlOfUploadedImageVhd `
        -LocalFilePath $Image -OverWrite:$false -ErrorAction SilentlyContinue -NumberOfUploaderThreads 32
}
catch {
    Write-Warning "Image already exists for $ImageVHD, not overwriting"
}


$parameters = @{}
$parameters.Add("sshkeyData", $sshKey)
$parameters.Add("adminUsername", $adminUsername)
$parameters.Add("imageName", $ImageName)
$parameters.Add("imageURI", $urlOfUploadedImageVhd)
$parameters.Add("vmName", $VMName)

write-Host "Start deployment"
 
if ($TESTONLY.IsPresent) {
    Test-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroup -Mode Incremental -TemplateFile $PSScriptRoot/azuredeploy.json -TemplateParameterObject $parameters
}
else {
    New-AzureRmResourceGroupDeployment -Name $resourceGroup -ResourceGroupName $resourceGroup -Mode Incremental -TemplateFile $PSScriptRoot/azuredeploy.json -TemplateParameterObject $parameters
}
