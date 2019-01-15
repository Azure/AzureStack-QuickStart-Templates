# Be sure to add a reference to this file in the head of ..\ValidatorNode.psm1

function test-CompareFirstBlockHash {
    Param([System.Collections.ArrayList] $validatorNodeList)
    Write-Host "Starting Test - Compare hash of each node's first block"

    $hashToCompare = $null
    foreach ($eachNode in $validatorNodeList) {
        $firstBlock = $eachNode.GetBlock(1)

        if ($firstBlock -eq $null)
        {throw [System.Exception] "The 1st block is empty"}

        if ($hashToCompare -eq $null) { $hashToCompare = $firstBlock.hash}

        if ($firstBlock.hash -ne $hashToCompare)
        {throw [System.Exception] "The 1st block blockhash does not match on all nodes"}
    }
    Write-Host "SUCCESS - All nodes have same block hash for the block# 1"
    Write-Host "End Test - Compare hash of each node's first block"
}
Export-ModuleMember -Function test-CompareFirstBlockHash
