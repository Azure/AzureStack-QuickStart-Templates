# Be sure to add a reference to this file in the head of ..\ValidatorNode.psm1

function test-AllNodesHavePassphraseFile {
    Param(
        [Parameter(Mandatory = $true)][System.Collections.ArrayList] $validatorNodeList,
        [Parameter(Mandatory = $true)][String] $resourceGroupName
    )
    Write-Host "Starting Test - All nodes have passphrase-[x].json file updated"

    # Get all the passphrase file entries
    $passphraseEntries = Get-AllPassphraseEntries -resourceGroupName $resourceGroupName

    # Loop over each validator node to make sure it has a related, and updated entry in the Azure Storage
    foreach ($eachNode in $validatorNodeList) {
        # Get the node's hostname
        $hostName = $eachNode.GetHostName()
        
        # Get the node's enode url value from parity
        $enodeUrl = $eachNode.GetEnodeUrl()

        # Get the related passphrase entry based on host name
        $relatedEntry = @($passphraseEntries | Where-Object hostname -eq $hostName)
        if ($relatedEntry.Length -lt 1)
        {throw [System.Exception] "Cannot find a passphrase-[x].json file for $hostName"}
        if ($relatedEntry.Length -gt 1)
        {throw [System.Exception] "Found multiple passphrase-[x].json files for $hostName"}

        # Validate that the enode url is correct
        if ($relatedEntry[0].enodeUrl -ne $enodeUrl)
        {throw [System.Exception] "$hostName related passphrase-[x].json file has a different enode than returned from parity"}
    }

    Write-Host "SUCCESS - All nodes have updated their related passphrase-[x].json file"
    Write-Host "End Test Test - All nodes have passphrase-[x].json file updated"
}

Export-ModuleMember -Function test-AllNodesHavePassphraseFile