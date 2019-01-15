# Be sure to add a reference to this file in the head of ..\ValidatorNode.psm1

# 1. Test that the prefund account can tranfer ether to another "new" account using any node
# 2. Check the balance on all other nodes for the prefund account and "new" account reflect the transfer

function test-CanTransferEther {
    Param(
        [Parameter(Mandatory = $true)][System.Collections.ArrayList] $validatorNodeList,
        [Parameter(Mandatory = $true)][String] $prefundPhrase
    )

    Write-Host "Starting Test - Can transfer ether"
    $testNode = $validatorNodeList[0]
    Write-Host "  Initial Testing Node: ${testNode}"

    # Get Prefund account and Balance
    $prefundAccount = $testNode.AccountFromPhrase($prefundPhrase);
    $prefundAccountStartingBalance = $testNode.GetAccountBalanceInWei($prefundAccount)
    Write-Host "  Prefund Account: ${prefundAccount}"
    Write-Host "  Starting Prefund Balance: ${prefundAccountStartingBalance}"

    # Create a test account
    $testAccountPhrase = Get-RandomStringPhrase(32)
    $testAccount = $testNode.AccountFromPhrase($testAccountPhrase)
    $testAccountStartBalance = $testNode.GetAccountBalanceInWei($testAccount)    
    Write-Host "  Test Account: ${testAccount}"
    Write-Host "  Starting Test Balance: ${testAccountStartBalance}"

    # Parity Method to send transaction 
    $amountToSend = "DE0B6B3A7640000";
    $parityMethod = " {`"method`":`"personal_sendTransaction`",`"params`":[{`"from`":`"$prefundAccount`",`"to`":`"$testAccount`",`"value`":`"0x${amountToSend}`", `"gasPrice`":`"0x0`"},`"${prefundPhrase}`"],`"id`":1,`"jsonrpc`":`"2.0`"}"
    $sendEtherTransaction = $testNode.ExecuteParityMethod($parityMethod)
    if ( $sendEtherTransaction -eq $null) {
        throw [System.Exception] "Unable to send transaction"
    }
    Write-Host "  Transaction Hash: ${sendEtherTransaction}"

    # Give transaction time to be mined
    $transactionReceipt = $testNode.GetMinedTransactionReceipt($sendEtherTransaction)
    Write-Host "  Transaction Mined at block #: $($transactionReceipt.blockNumberInt)"

    foreach ($eachNode in $validatorNodeList) {
        $testAccountEndBalance = $eachNode.GetAccountBalanceInWei($testAccount)    
        if (-not $testAccountEndBalance.Equals([System.Numerics.BigInteger]::Parse("0${amountToSend}", 'AllowHexSpecifier'))) {
            throw [System.Exception] "Test account balance does not reflect transaction amount on node: $eachNode"
        }    
    }
    
    # Remove the test account from the parity wallet
    $removedTestAccount = $testNode.KillAccount($testAccount, $testAccountPhrase)
    if ($removedTestAccount) {Write-Host "  Removed $testAccount from parity wallet"}


    Write-Host "SUCCESS - Ether transfer successful"
    Write-Host "End Test - Can transfer ether"
}

Export-ModuleMember -Function test-CanTransferEther