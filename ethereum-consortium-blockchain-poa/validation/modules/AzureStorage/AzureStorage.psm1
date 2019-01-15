################################################
#  Include required files
################################################
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

function test-AzureStorageFiles {
    Param(
        [Parameter(Mandatory = $true)][String] $resourceGroupName
    )

    Write-Host "Starting Test - Azure Storage Files"

    # Get the number of nodes that should have been deployed
    $deploymentGroup = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName)[-1]
    if ($deploymentGroup -eq $null) {
        throw [System.Exception] "Could not load information about the Resource Group deployments"
    }
    $parameters = $deploymentGroup.Parameters
    $numOfNodes = $parameters['numVLNodesRegion'].Value * $parameters['regionCount'].Value

    # Get information about all the blobs in the storage account
    $blobs = (Get-AllAzureStorageBlobs -resourceGroupName $resourceGroupName)

    # Does AdminValidatorSet.sol.abi exist?
    $abiFile = ($blobs | Where-Object {$_.Name -like "AdminValidatorSet.sol.abi"})
    if ($abiFile -eq $null) {throw [System.Exception] "Azure Storage - AdminValidatorSet.sol.abi file not found"}
    if ($abiFile.ICloudBlob.Properties.Length -eq 0) {throw [System.Exception] "Azure Storage - AdminValidatorSet.sol.abi file is blank"}

    # Does spec.json file exist
    $specFile = ($blobs | Where-Object {$_.Name -like "spec.json"})
    if ($specFile -eq $null) {throw [System.Exception] "Azure Storage - spec.json file not found"}
    if ($specFile.ICloudBlob.Properties.Length -eq 0) {throw [System.Exception] "Azure Storage - spec.json file is blank"}

    # Passphrase files
    $passphraseBlobs = ($blobs | Where-Object {$_.Name -like "passphrase*" })
    if ($passphraseBlobs -eq $null) {throw [System.Exception] "Azure Storage - No passphrase-[x].json files found"}
    if ($passphraseBlobs.Length -lt $numOfNodes) {throw [System.Exception] "Azure Storage - There should be $numOfNodes passphrase-[x].json files created, but only $($passphraseBlobs.Length) were found"}
    
    # Leased Passphrase files
    $passphraseLeasedBlobs = ($blobs | Where-Object {$_.Name -like "passphrase*" -and $_.ICloudBlob.Properties.LeaseStatus -eq "Locked" })
    if ($passphraseLeasedBlobs -eq $null) {throw [System.Exception] "Azure Storage - No leased passphrase-[x].json files found"}
    if ($passphraseLeasedBlobs.Length -lt $numOfNodes) {throw [System.Exception] "Azure Storage - Only $($passphraseLeasedBlobs.Length) passphrase-[x].json files were leased. Expected $numOfNodes"}

    # Check passphrase contents
    $passphraseEntries = Get-AllPassphraseEntries -resourceGroupName $resourceGroupName
    foreach ($eachEntry in $passphraseEntries) {
        if (-not [bool]($eachEntry.PSobject.Properties.name -match "passphraseUri"))
        {throw [System.Exception] "Azure Storage - A passphrase-[x].json is missing property 'passphraseUri'"}
        
        if (-not [bool]($eachEntry.PSobject.Properties.name -match "enodeUrl"))
        {throw [System.Exception] "Azure Storage - A passphrase-[x].json is missing property 'enodeUrl'"}

        if (-not [bool]($eachEntry.PSobject.Properties.name -match "hostname"))
        {throw [System.Exception] "Azure Storage - A passphrase-[x].json is missing property 'hostname'"}
    }

    Write-Host "SUCCESS - Azure Storage Files"
    Write-Host "End Test - Azure Storage Files"
}

function Get-AllPassphraseEntries() {
    [OutputType([Object[]])]
    Param([Parameter(Mandatory = $true)][String] $resourceGroupName)
    $blobs = (Get-AllAzureStorageBlobs -resourceGroupName $resourceGroupName)
    $passphraseBlobs = ($blobs | Where-Object {$_.Name -like "passphrase*" })
    return ($passphraseBlobs | ForEach-Object -Process {$_.ICloudBlob.DownloadText() | ConvertFrom-Json})    
}

function Get-AllAzureStorageBlobs() {
    [OutputType([Object[]])]
    Param([Parameter(Mandatory = $true)][String] $resourceGroupName)
    $storageContext = (Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName)[0].Context
    $storageContainer = (Get-AzureStorageContainer -Context $storageContext)[0].Name
    return (Get-AzureStorageBlob -Context $storageContext -Container $storageContainer)
}

function Get-AzureBlobFileContents() {
    [OutputType([String])]
    Param(
        [Parameter(Mandatory = $true)][String] $resourceGroupName,
        [Parameter(Mandatory = $true)][String] $fileName
    )
    $storageContext = (Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName)[0].Context
    $storageContainer = (Get-AzureStorageContainer -Context $storageContext)[0].Name

    $blob = Get-AzureStorageBlob -Context $storageContext -Container $storageContainer -Blob $fileName
    $blobText = $blob.ICloudBlob.DownloadText()
    return $blobText
}

Export-ModuleMember -Function test-AzureStorageFiles
Export-ModuleMember -Function Get-AzureBlobFileContents
Export-ModuleMember -Function Get-AllPassphraseEntries
