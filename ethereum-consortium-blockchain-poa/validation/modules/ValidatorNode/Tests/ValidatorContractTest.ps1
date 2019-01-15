# Be sure to add a reference to this file in the head of ..\ValidatorNode.psm1

function test-ValidatorContract {
    Param(
        [Parameter(Mandatory = $true)][System.Collections.ArrayList] $validatorNodeList,
        [Parameter(Mandatory = $true)][String] $ethereumValidatorAdminPrivateKey
    )
    Write-Host "Starting Test - Validator Contract"
    $testNode = $validatorNodeList[0];
    Write-Host "  Initial Testing Node: ${testNode}"

    $ethereumValidatorAdminPassphrase = Get-RandomStringPhrase(32)
    # Add the admin account to the testNode wallet using https://wiki.parity.io/JSONRPC-parity_accounts-module#parity_newaccountfromsecret  method
    $ethereumValidatorAdminAccount = $testNode.AccountFromSecret("0x" + $ethereumValidatorAdminPrivateKey, $ethereumValidatorAdminPassphrase)
    Write-Host "  Validator admin account private key evaluates to Account#: $ethereumValidatorAdminAccount"
    Write-Host "  Validator admin account added to parity wallet with passphrase: $ethereumValidatorAdminPassphrase"

    ValidatorAdminSameOnAllNodes `
        -validatorNodeList $validatorNodeList `
        -ethereumValidatorAdminAccount $ethereumValidatorAdminAccount

    CanUpdateAdminAlias `
        -validatorNodeList $validatorNodeList `
        -ethereumValidatorAdminPrivateKey $ethereumValidatorAdminPrivateKey `
        -ethereumValidatorAdminAccount $ethereumValidatorAdminAccount

    AddRemoveAdmin `
        -validatorNodeList $validatorNodeList `
        -ethereumValidatorAdminPrivateKey $ethereumValidatorAdminPrivateKey `
        -ethereumValidatorAdminAccount $ethereumValidatorAdminAccount
        
    $removeAdminAccount = $testNode.KillAccount($ethereumValidatorAdminAccount, $ethereumValidatorAdminPassphrase)
    if ($removeAdminAccount) {Write-Host "  Removed validator admin account: $ethereumValidatorAdminAccount from parity wallet"}

    Write-Host "SUCCESS - Validator contract is fully operational"
    Write-Host "End Test - Validator Contract"
}

function ValidatorAdminSameOnAllNodes {
    Param(
        [Parameter(Mandatory = $true)][System.Collections.ArrayList] $validatorNodeList,
        [Parameter(Mandatory = $true)][String] $ethereumValidatorAdminAccount
    )
    Write-Host "Starting Test - Initial Validator Admin in contract 'getAdmins() function"

    foreach ($eachNode in $validatorNodeList) {
        $adminArray = $eachNode.GetAdmins()
        
        if ($adminArray -eq $null) { throw [System.Exception] "No validation admins were found" }

        if (-not [System.Linq.Enumerable]::Any($adminArray, [Func[object, bool]] { param($x) $x.toString() -like "*$ethereumValidatorAdminAccount*" })) {
            throw [System.Exception] "Admin not found in validatorcontract"
        }        
    }

    Write-Host "SUCCESS - Initial validator admin account $ethereumValidatorAdminAccount found on all nodes"
    Write-Host "End Test - Initial Validator Admin in contract 'getAdmins() function"
}

function CanUpdateAdminAlias {
    Param(
        [Parameter(Mandatory = $true)][System.Collections.ArrayList] $validatorNodeList,
        [Parameter(Mandatory = $true)][String] $ethereumValidatorAdminPrivateKey,
        [Parameter(Mandatory = $true)][String] $ethereumValidatorAdminAccount
    )
    Write-Host "Starting Test - Can update admin alias"
    
    $testNode = $validatorNodeList[0];
    $startingAlias = $testNode.GetAliasForAdmin($ethereumValidatorAdminAccount);
    Write-Host "  Initial alias for account: $ethereumValidatorAdminAccount is $startingAlias"
    
    $testAlias = Get-RandomStringPhrase(10)
    Write-Host "  Updating alias to: $testAlias"
    $updateAliasTransactionHash = $testNode.UpdateAdminAlias($ethereumValidatorAdminAccount, $testAlias , $ethereumValidatorAdminPrivateKey)
    $updateAliasTransactionReceipt = $testNode.GetMinedTransactionReceipt($updateAliasTransactionHash)    
    Write-Host "  Updated alias to: $testAlias in Block#: $($updateAliasTransactionReceipt.blockNumberInt), Transaction #: $updateAliasTransactionHash"
    
    Start-Sleep 2 # Allow time for block to be mined

    # make sure each node has the latest admin alias
    foreach ($eachNode in $validatorNodeList) {
        $eachNodeAlias = $eachNode.GetAliasForAdmin($ethereumValidatorAdminAccount)        
        if ($eachNodeAlias -ne $testAlias) { throw [System.Exception] "Alias was not updated on $eachNode" }
    }

    Write-Host "SUCCESS - Admin alias was updated on all nodes"
    Write-Host "End Test - Can update admin alias"
}

function AddRemoveAdmin {
    Param(
        [Parameter(Mandatory = $true)][System.Collections.ArrayList] $validatorNodeList,
        [Parameter(Mandatory = $true)][String] $ethereumValidatorAdminPrivateKey,
        [Parameter(Mandatory = $true)][String] $ethereumValidatorAdminAccount
    )
    Write-Host "Starting Test - Can add and remove admins"

    $testNode = $validatorNodeList[0];
    $validatorContractAddress = '0x0000000000000000000000000000000000000006'

    Write-Host "  Current admins: $([string]::Join(', ', $testnode.GetAdmins()))"

    # Generate a new random account to assign as a validator admin
    $testAccountPhrase = Get-RandomStringPhrase(32)
    $testAccount = $testNode.AccountFromPhrase($testAccountPhrase)

    # Propose the new admin
    Write-Host "  Proposing to add $testAccount as a new admin with Passphrase: $testAccountPhrase"
    $proposeTransactionHash = $testNode.ProposeAdmin($ethereumValidatorAdminAccount, $testAccount, "newAdmin", $ethereumValidatorAdminPrivateKey)
    $proposeTransactionReceipt = $testNode.GetMinedTransactionReceipt($proposeTransactionHash)
    Write-Host "  Proposed in Block#: $($proposeTransactionReceipt.blockNumberInt), Transaction #: $proposeTransactionHash"
    
    # Make sure the new admin was actually added to the contract
    $newAdmins = $testnode.GetAdmins();
    Write-Host "  New admins: $([string]::Join(', ', $testnode.GetAdmins()))"
    if (-not [System.Linq.Enumerable]::Any($newAdmins, [Func[object, bool]] { param($x) $x.toString() -like "*$testAccount*" })) {
        throw [System.Exception] "Admin not found in getAdmins() function call to the contract"
    }
       
    # Add new validator    
    $validator1PassPhrase = Get-RandomStringPhrase(32)
    $validator1Account = $testNode.AccountFromPhrase($validator1PassPhrase)
    Write-Host "  Adding $Validator1Account as a new validator with Passphrase: $validator1PassPhrase"
    $addValidator1TransactionHash = $testNode.AddValidator_UsingPassphrase($testAccount, $validatorContractAddress, $validator1Account, $testAccountPhrase)
    $addValidator1TransactionReceipt = $testNode.GetMinedTransactionReceipt($addValidator1TransactionHash)
    Write-Host "  Added $Validator1Account as validator in Block#: $($addValidator1TransactionReceipt.blockNumberInt), Transaction #: $addValidator1TransactionHash"

    # See if validator is available in the list
    $validators = $testNode.getValidators();
    # Todo: add wait for Parity Log message "Applying validator set change signalled at block 111"
    #if (-not [System.Linq.Enumerable]::Any($validators, [Func[object, bool]] { param($x) $x.toString() -like "*$validator1Account*" })) {
    #throw [System.Exception] "Validator not added to contract"
    #}   

    # Remove new validator
    Write-Host "  Removing $Validator1Account as a validator"
    $removeValidator1TransactionHash = $testNode.RemoveValidator_UsingPassphrase($testAccount, $validatorContractAddress, $validator1Account, $testAccountPhrase)
    $removeValidator1TransactionReceipt = $testNode.GetMinedTransactionReceipt($addValidator1TransactionHash)
    Write-Host "  Removed $Validator1Account as validator in Block#: $($removeValidator1TransactionReceipt.blockNumberInt), Transaction #: $removeValidator1TransactionHash"
    $removeTestNode = $testNode.KillAccount($validator1Account, $validator1PassPhrase)
    if ($removeTestNode) {Write-Host "  Removed validator account: $validator1Account from parity wallet"}

    # Todo: add another validator, and make sure it is actually removed when the admin account is removed

    # Vote to remove the new admin
    Write-Host "  Voting to remove $testAccount as an admin"
    $voteAgainstTransactionHash = $testNode.VoteAgainstAdmin($ethereumValidatorAdminAccount, $testAccount, $ethereumValidatorAdminPrivateKey)
    $voteAgainstTransactionReceipt = $testNode.GetMinedTransactionReceipt($voteAgainstTransactionHash)
    Write-Host "  Voted in Block#: $($voteAgainstTransactionReceipt.blockNumberInt), Transaction #: $voteAgainstTransactionHash"

    Write-Host "  Voting again to remove $testAccount as an admin"
    Start-Sleep 4 # Allow time for previous block to be mined
    $voteAgainst2TransactionHash = $testNode.VoteAgainst_UsingPassphrase($testAccount, $validatorContractAddress, $testAccount, $testAccountPhrase)
    $voteAgainst2TransactionReceipt = $testNode.GetMinedTransactionReceipt($voteAgainst2TransactionHash)
    Write-Host "  Voted in Block#: $($voteAgainst2TransactionReceipt.blockNumberInt), Transaction #: $voteAgainst2TransactionHash"

    # Make sure the new admin was removed from the admin list.
    $finalAdmins = $testnode.GetAdmins()
    Write-Host "  Final admins: $([string]::Join(', ', $finalAdmins))"
    if ([System.Linq.Enumerable]::Any($finalAdmins, [Func[object, bool]] { param($x) $x.toString() -like "*$testAccount*" })) {
        throw [System.Exception] "Admin was not removed from getAdmins() function call to the contract"
    }   

    $removedTestAccount = $testNode.KillAccount($testAccount, $testAccountPhrase)
    if ($removedTestAccount) {Write-Host "  Removed $testAccount from parity wallet"}

    Write-Host "End Test - Can add and remove admins"
}

Export-ModuleMember -Function test-ValidatorContract