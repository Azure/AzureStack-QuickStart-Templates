# Be sure to add a reference to this file in the head of ..\ValidatorNode.psm1

function test-CompareMultiBlockHashs {
    Param([System.Collections.ArrayList] $validatorNodeList)
    Write-Host "Starting Test - Compare hash of node's blocks"

    $hashsToCompare = New-Object System.Collections.ArrayList
    $lastBlockNumber = $null
    # MaxBlockCount
    $maxBlockCount = 10
    
    # Assert Multiple blocks
    Describe "Sync Multi Blocks" { 
        It "Matches All Node Blocks " {
            foreach ($eachNode in $validatorNodeList) {   
                # get latest blocks when the first node come
                if($lastBlockNumber -eq $null)
                {   # padded the last block number since delaye
                    $lastBlockNumber = $eachNode.CurrentBlockNumber() - 2
                }
        
                if($lastBlockNumber -lt $maxBlockCount)
                {$compareBlockCount = $lastBlockNumber}
                else {$compareBlockCount = $maxBlockCount}
        
                $nodeHashs = $eachNode.GetBlockHashsByRange($lastBlockNumber, $compareBlockCount)

                # get blocks when the first node come
                if($hashsToCompare.Count -eq 0)
                {
                    $hashsToCompare = New-Object System.Collections.ArrayList(,$nodeHashs)
                }
            }
            for ($i = 0; $i -lt $hashsToCompare.Count; $i++) 
            {          
                $hashsToCompare[$i] | Should Be $nodeHashs[$i]
            }
        }
    }
}


Export-ModuleMember -Function test-CompareMultiBlockHashs
