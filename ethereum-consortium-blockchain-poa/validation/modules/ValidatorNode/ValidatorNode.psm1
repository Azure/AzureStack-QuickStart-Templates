################################################
#  Include required files
################################################
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
try {
    . ("$ScriptDirectory\HelperFunctions.ps1")
    . ("$ScriptDirectory\Tests\CompareFirstBlockHash.ps1")
    . ("$ScriptDirectory\Tests\CanCreateContract.ps1")
    . ("$ScriptDirectory\Tests\MultiNetworkLastestBlockHash.ps1")
    . ("$ScriptDirectory\Tests\ValidatorContractTest.ps1")
    . ("$ScriptDirectory\Tests\AllNodesHavePassphraseFile.ps1")
    . ("$ScriptDirectory\Tests\AdminSite.ps1")
    . ("$ScriptDirectory\Tests\OMSAgent.ps1")
}
catch {
    Write-Host "Error while loading supporting PowerShell Scripts" 
    throw $_.Exception
}

################################################
# Initialize SSH modules
################################################
if (Get-Module -ListAvailable -Name PoSH-SSH) {
    Write-Host "PoSH-SSH module exists"
}
else {
    Write-Host "PoSH-SSH module does not exist... Installing now"
    Install-Module -name PoSH-SSH -Force -Scope CurrentUser
}
Import-Module PoSH-SSH

# Create package.json
npm init

################################################
# Install Web3
################################################
$NpmListOfWeb3 = (npm list web3 --depth=0)
$Web3Installed = [System.Linq.Enumerable]::Any($NpmListOfWeb3, [Func[object, bool]] { param($x) $x.toString() -like '*web3*' })
if ($Web3Installed)
{ Write-Host "NPM Package ethereumjs-tx already installed" }
else {
    Write-Host "Installing NPM Package web3"
    npm install web3@0.20.2
}

################################################
# Install npm install ethereumjs-tx
################################################

$NpmListOfEthereumjs = (npm list ethereumjs-tx --depth=0)
$EthereumjsInstalled = [System.Linq.Enumerable]::Any($NpmListOfEthereumjs, [Func[object, bool]] { param($x) $x.toString() -like '*ethereumjs*' })
if ($EthereumjsInstalled)
{ Write-Host "NPM Package ethereumjs-tx already installed" }
else {
    Write-Host "Installing NPM Package ethereumjs-tx"
    npm install ethereumjs-tx
}

function New-NodeSshSession {
    [OutputType([SSH.SshSession])]
    Param(
        [Parameter(Mandatory = $true)][String] $hostName, 
        [Parameter(Mandatory = $true)][int] $port,
        [Parameter(Mandatory = $true)][String] $userName,
        [Parameter(Mandatory = $true)][String] $password
    )
    Write-Host "Starting SSH Session to ${hostName}:${port}"

    # Create credentials
    $secpasswd = ConvertTo-SecureString $password -AsPlainText -Force;
    $sshCredential = (New-Object System.Management.Automation.PSCredential ($userName, $secpasswd));

    # Open SSH Session   
    $sshSession = (New-SSHSession -port $port -computername $hostName -Credential $sshCredential -AcceptKey:$true -Force:$true)
    if ($sshSession -eq $null)
    { throw [System.Exception] "Unable to create SSH Session to ${hostName}:${port}" }

    return $sshSession
}

function New-ValidatorNode {
    [OutputType([ValidatorNode])]
    Param(
        [Parameter(Mandatory = $true)][String] $hostName,
        [Parameter(Mandatory = $true)][int] $port,
        [Parameter(Mandatory = $true)][int] $remoteRpcPortNumber,
        [Parameter(Mandatory = $true)][int] $portToForwardToRpc,
        [Parameter(Mandatory = $true)][String] $userName,
        [Parameter(Mandatory = $true)][String] $password
    )
    return [ValidatorNode]::new($hostName, $port, $remoteRpcPortNumber, $portToForwardToRpc, $userName, $password);
}

function Get-BigIntegerFromHex {
    [OutputType([System.Numerics.BigInteger])]
    Param(
        [Parameter(Mandatory = $true)][String] $intAsHex
    )
    # Positive big int hex values must start with a zero.
    # https://stackoverflow.com/questions/30119174/converting-a-hex-string-to-its-biginteger-equivalent-negates-the-value
    $balanceInUnsignedHex = "0" + $intAsHex.Substring(2, $intAsHex.Length - 2)        
    return [System.Numerics.BigInteger]::Parse($balanceInUnsignedHex, 'AllowHexSpecifier')
}

class ValidatorNode {
    [String] $PublicHostName
    [int] $SshPortNumber
    [int] $RemoteRpcPortNumber
    [int] $LocalRpcPortNumber
    [String] $AdminUserName
    [String] $AdminPassword
    [SSH.SshSession] $SshSession
    
    # Initialize path to Web3 Helper Functions Files
    hidden [String]  $Web3HelperFunctionsPath = (${PSScriptRoot} + "/Web3HelperFunctions.js").Replace('\', '/')

    #region ############## Start Class Constructor ######################
    ValidatorNode(
        [String] $publicHostName,
        [int] $sshPortNumber,
        [int] $remoteRpcPortNumber,
        [int] $portToForwardToRpc,
        [String] $adminUserName,
        [String] $adminPassword) {

        $this.PublicHostName = $publicHostName
        $this.SshPortNumber = $sshPortNumber
        $this.RemoteRpcPortNumber = $remoteRpcPortNumber
        $this.LocalRpcPortNumber = $portToForwardToRpc
        $this.AdminUserName = $adminUserName
        $this.AdminPassword = $adminPassword

        $this.OpenSshSession()

        Write-Host("  Path to Web3 Helper file: $this.Web3HelperFunctionsPath");
    }
    #endregion ############## End Class Constructor ######################
    
    #region ############## Start SSH Methods ######################
    OpenSshSession () {
        # Start the new SSH Session
        $this.SshSession = New-NodeSshSession `
            -port $this.SshPortNumber `
            -hostName $this.PublicHostName `
            -userName $this.AdminUserName `
            -password $this.AdminPassword

        # Forward a local port to the RPC endpoint of the remote ethereum client
        New-SSHLocalPortForward -BoundHost 127.0.0.1 -BoundPort $this.LocalRpcPortNumber -RemoteAddress 127.0.0.1 -RemotePort $this.RemoteRpcPortNumber -SSHSession $this.SshSession
    }

    CloseSshSession () {
        if ($this.SshSession -ne $null -and $this.SshSession.Connected -eq $true ) {
            $removeSession = Remove-SSHSession $this.SshSession
            if (-NOT $removeSession)
            { throw [System.Exception] "Unable to remove SSH Session" }
        }
    }
    #endregion ############## End SSH Methods ######################

    #region ############## Start WEB3 Ethereum Methods ######################

    # ExecuteWeb3Method() functions are used to execute a specfied method in the Web3HelperFunctions.js file and to pass in the parameters
    [String] ExecuteWeb3Method([String] $MethodName)
    {return $this.ExecuteWeb3Method($MethodName, $null)}

    [String] ExecuteWeb3Method([String] $MethodName, [String[]] $parameters ) {
        $methodParameters = $null;
        if ($parameters -ne $null) {
            # Wrap the parameters in a quotes before passing to command line
            for ($i = 0; $i -lt $parameters.Count; $i++) {
                $parameters[$i] = "\`"" + $parameters[$i] + "\`""
            }
            # Comma separate the parameters
            $separator = ", "
            $methodParameters = [string]::Join($separator, $parameters)
        }
        # Create the javascript code
        $nodeCommand = "require(\`"$($this.Web3HelperFunctionsPath)\`").$MethodName($methodParameters)"
        # Execute the javascript code using NodeJS
        $nodeReturnValue = (node -e "${nodeCommand}" "127.0.0.1" $this.LocalRpcPortNumber)
        return $nodeReturnValue;
    }

    [String[]] GetAdmins() { return ($this.ExecuteWeb3Method("getAdmins") | ConvertFrom-Json) }

    [String[]] GetProposedAdmins() { return ($this.ExecuteWeb3Method("getProposedAdmins") | ConvertFrom-Json) }

    [String[]] GetValidators() { return ($this.ExecuteWeb3Method("getValidators") | ConvertFrom-Json) }

    [String[]] GetValidatorCapacity() { return ($this.ExecuteWeb3Method("getValidatorCapacity") | ConvertFrom-Json) }

    [String[]] GetAliasForAdmin([String] $accountAddress)
    { return ($this.ExecuteWeb3Method("getAliasForAdmin", $accountAddress)) }

    [String] UpdateAdminAlias([String]$fromAccountAddress, [String]$alias, [String]$privateKey) {        
        # Returns the transaction hash
        $transactionHash = $this.ExecuteWeb3Method("updateAdminAlias", ($fromAccountAddress, [String]$alias, [String]$privateKey))
        return $transactionHash
    }

    [String] ProposeAdmin([String]$fromAccountAddress, [String]$newAccount, [String]$alias, [String]$privateKey) {        
        # Returns the transaction hash
        $transactionHash = $this.ExecuteWeb3Method("proposeAdmin", ($fromAccountAddress, $newAccount, $alias, $privateKey))
        return $transactionHash
    }

    [String] VoteAgainstAdmin([String]$fromAccountAddress, [String]$voteAgainstAccount, [String]$privateKey) {        
        # Returns the transaction hash
        $transactionHash = $this.ExecuteWeb3Method("voteAgainst", ($fromAccountAddress, $voteAgainstAccount, $privateKey))
        return $transactionHash
    }

    [String] AddValidator([String]$fromAccountAddress, [String]$newValidatorAddress, [String]$privateKey) {        
        # Returns the transaction hash
        $transactionHash = $this.ExecuteWeb3Method("addValidators", ($fromAccountAddress, $newValidatorAddress, $privateKey))
        return $transactionHash
    }

    [String] AddValidator_UsingPassphrase([String]$fromAccountAddress, [String]$contractAddress, [String]$newValidatorAddress, [String]$passphrase) {        
        # Get the raw transaction data, to then sign
        $transactionData = $this.ExecuteWeb3Method("addValidatorData", $newValidatorAddress)
        # Send and sign the raw transaction data
        $parityMethod = "{`"method`":`"personal_sendTransaction`",`"params`":[{`"from`":`"$fromAccountAddress`",`"to`":`"$contractAddress`",`"value`":`"0x0`",`"data`":`"${transactionData}`"},`"${passphrase}`"],`"id`":1,`"jsonrpc`":`"2.0`"}"
        $transactionHash = $this.ExecuteParityMethod($parityMethod)      
        return $transactionHash
    }

    [String] RemoveValidator_UsingPassphrase([String]$fromAccountAddress, [String]$contractAddress, [String]$validatorAddress, [String]$passphrase) {        
        # Get the raw transaction data, to then sign
        $transactionData = $this.ExecuteWeb3Method("removeValidatorData", $validatorAddress)
        # Send and sign the raw transaction data
        $parityMethod = "{`"method`":`"personal_sendTransaction`",`"params`":[{`"from`":`"$fromAccountAddress`",`"to`":`"$contractAddress`",`"value`":`"0x0`",`"data`":`"${transactionData}`"},`"${passphrase}`"],`"id`":1,`"jsonrpc`":`"2.0`"}"
        $transactionHash = $this.ExecuteParityMethod($parityMethod)      
        return $transactionHash
    }
    

    [String] VoteAgainst_UsingPassphrase([String]$fromAccountAddress, [String]$contractAddress, [String]$adminAccount, [String]$passphrase) {        
        # Get the raw transaction data, to then sign
        $transactionData = $this.ExecuteWeb3Method("voteAgainstData", $adminAccount)
        # Send and sign the raw transaction data
        $parityMethod = "{`"method`":`"personal_sendTransaction`",`"params`":[{`"from`":`"$fromAccountAddress`",`"to`":`"$contractAddress`",`"value`":`"0x0`",`"data`":`"${transactionData}`"},`"${passphrase}`"],`"id`":1,`"jsonrpc`":`"2.0`"}"
        $transactionHash = $this.ExecuteParityMethod($parityMethod)      
        return $transactionHash
    }

    #endregion ############## End WEB3 Ethereum Methods ######################

    #region ############## Start Ethereum Network Methods ######################

    [int] CurrentBlockNumber() {
        $parityMethod = "{`"method`":`"eth_blockNumber`",`"params`":[],`"id`":1,`"jsonrpc`":`"2.0`"}"
        return $this.ExecuteParityMethod($parityMethod)
    }

    [PSCustomObject] GetBlock([int]$blockNumber) {
        $getBlockByNumberCommand = "{`"method`":`"eth_getBlockByNumber`",`"params`":[`"#####`",true],`"id`":1,`"jsonrpc`":`"2.0`"}"
        $getBlockCommandFull = $getBlockByNumberCommand.Replace("#####", '0x{0:X}' -f $blockNumber)   
        return $this.ExecuteParityMethod($getBlockCommandFull)
    }
    
    [PSCustomObject] GetBlockHashsByRange([int]$lastBlock, [int]$range)
    {        
        $blockHashs = New-Object System.Collections.ArrayList
        for($idx = ($lastBlock-$range); $idx -lt $lastBlock; $idx++){
            $block = $this.GetBlock($idx)
            $blockHashs.Add($block.hash) > $null
        }
        return $blockHashs
    }

    [PSCustomObject] GetTransactionByHash([String]$transactionHash) {
        # Parity Example
        # curl --data '{"method":"eth_getTransactionByHash","params":["0xb903239f8543d04b5dc1ba6579132b143087c68db1b2168786408fcbce568238"],"id":1,"jsonrpc":"2.0"}' -H "Content-Type: application/json" -X POST localhost:8545
        $parityMethod = "{`"method`":`"eth_getTransactionByHash`",`"params`":[`"$transactionHash`"],`"id`":1,`"jsonrpc`":`"2.0`"}"
        return $this.ExecuteParityMethod($parityMethod)
    }

    [PSCustomObject] GetMinedTransactionReceipt([String]$transactionHash) {
        $maxLoops = 5
        $currentLoop = 0
        $receipt = $this.GetTransactionReceipt($transactionHash)
        while ($receipt.blockHash -eq $null) {
            Start-Sleep -Seconds 2
            $currentLoop++
            if ($currentLoop -gt $maxLoops) {
                throw [System.Exception] "Transaction: $transactionHash was not mined in time"
            }
            $receipt = $this.GetTransactionReceipt($transactionHash)
        }
        # Add a new field with the blockNumber converted to BigInt
        $receipt | Add-Member blockNumberInt (Get-BigIntegerFromHex $receipt.blockNumber)
        return $receipt
    }
        
    [PSCustomObject] GetTransactionReceipt([String]$transactionHash) {
        # Parity Example
        # curl --data '{"method":"eth_getTransactionReceipt","params":["0x444172bef57ad978655171a8af2cfd89baa02a97fcb773067aef7794d6913374"],"id":1,"jsonrpc":"2.0"}' -H "Content-Type: application/json" -X POST localhost:8545
        $parityMethod = "{`"method`":`"eth_getTransactionReceipt`",`"params`":[`"$transactionHash`"],`"id`":1,`"jsonrpc`":`"2.0`"}"
        return $this.ExecuteParityMethod($parityMethod)
    }

    [String] CallContract([String]$from, [String]$to, [String]$data) {
        #curl --data '{"method":"eth_call","params":[{"from":"0x407d73d8a49eeb85d32cf465507dd71d507100c1","to":"0xa94f5374fce5edbc8e2a8697c15331677e6ebf0b","value":"0x186a0"}],"id":1,"jsonrpc":"2.0"}' -H "Content-Type: application/json" -X POST localhost:8545
        $parityMethod = "{`"method`":`"eth_call`",`"params`":[{`"from`":`"$from`",`"to`":`"$to`",`"data`":`"$data`"}, `"latest`"],`"id`":1,`"jsonrpc`":`"2.0`"}"
        return $this.ExecuteParityMethod($parityMethod)
    }
    
    [String] AccountFromPhrase([String] $phrase) {
        $parityMethod = "{`"method`":`"parity_newAccountFromPhrase`",`"params`":[`"$phrase`",`"$phrase`"],`"id`":1,`"jsonrpc`":`"2.0`"}"
        return $this.ExecuteParityMethod($parityMethod)
    }

    [bool] KillAccount([String]$account, [String]$accountPassword) {
        $parityMethod = "{`"method`":`"parity_killAccount`",`"params`":[`"$account`", `"$accountPassword`"],`"id`":1,`"jsonrpc`":`"2.0`"}"
        return $this.ExecuteParityMethod($parityMethod)
    }    

    [String] AccountFromSecret([String] $privateKey, [String] $unlockPassPhrase) {
        # Returns the address that the private key is for
        # $unlockPassPhrase is the password that you want to use to unlock this account.

        # Example method
        # curl --data '{"method":"parity_newAccountFromSecret","params":["0x1db2c0cf57505d0f4a3d589414f0a0025ca97421d2cd596a9486bc7e2cd2bf8b","hunter2"],"id":1,"jsonrpc":"2.0"}' -H "Content-Type: application/json" -X POST localhost:8545
        $parityMethod = "{`"method`":`"parity_newAccountFromSecret`",`"params`":[`"$privateKey`",`"$unlockPassPhrase`"],`"id`":1,`"jsonrpc`":`"2.0`"}"
        return $this.ExecuteParityMethod($parityMethod)
    }

    [String] GetEnodeUrl() {
        # Returns the node's enode url

        # Example method
        # curl --data '{"method":"parity_enode","params":[],"id":1,"jsonrpc":"2.0"}' -H "Content-Type: application/json" -X POST localhost:8545
        $parityMethod = "{`"method`":`"parity_enode`",`"params`":[],`"id`":1,`"jsonrpc`":`"2.0`"}"
        return $this.ExecuteParityMethod($parityMethod)
    }


    [System.Numerics.BigInteger] GetAccountBalanceInWei([String] $account) {
        # Parity Example Method
        #    curl --data '{"method" : "eth_getBalance",  "params" :[ "0x407d73d8a49eeb85d32cf465507dd71d507100c1"],"id":1,"jsonrpc":"2.0"}' -H "Content-Type: application/json" -X POST localhost:8545
        $parityMethod = "{`"method`":`"eth_getBalance`",`"params`":[`"$account`"],`"id`":1,`"jsonrpc`":`"2.0`"}"
        $balance = $this.ExecuteParityMethod($parityMethod)
        return Get-BigIntegerFromHex $balance
    }

    [System.Numerics.BigInteger] GetAccountBalance([String] $account, [String] $unit) {
        $acccountBalanceInWei = $this.GetAccountBalanceInWei($account)
        $newBalance = $this.ExecuteWeb3Method('fromWei', ($acccountBalanceInWei.ToString(), $unit))
        return $newBalance
    }

    [String] SignMessage([String]$address, [String]$unlockPassPhrase, [String] $data) {
        # Signs the data
        # $unlockPassPhrase is the password that you want to use to unlock this account.

        # Example method
        # curl --data '{"method":"parity_signMessage","params":["0xc171033d5cbff7175f29dfd3a63dda3d6f8f385e","password1","0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a"],"id":1,"jsonrpc":"2.0"}' -H "Content-Type: application/json" -X POST localhost:8545
        # Parameters
        # 1. Address - Account which signs the message.
        # 2. String - Passphrase to unlock the account.
        # 3. Data - Hashed message.
        $parityMethod = "{`"method`":`"parity_signMessage`",`"params`":[`"$address`",`"$unlockPassPhrase`",`"$data`"],`"id`":1,`"jsonrpc`":`"2.0`"}"
        return $this.ExecuteParityMethod($parityMethod)
    }


    [PSCustomObject] ExecuteParityMethod([String] $methodToExecute) {
        if ( $this.SshSession -eq $null -or $this.SshSession.Connected -eq $false) { $this.OpenSshSession() }

        $bashCommand = "echo '${methodToExecute}' | nc -U -q 1 /opt/parity/jsonrpc.ipc"
        $sshCommand = (Invoke-SSHCommand $this.SshSession -Command $bashCommand)
        if ( $sshCommand.ExitStatus -ne 0) {
            $error = $sshCommand.Error
            throw [System.Exception] "Error executing parity method: ${error}" 
        }     
        $outputJsonObject = $sshCommand.Output[0] | ConvertFrom-Json
        return $outputJsonObject.result  
    }

    #endregion ############## End Ethereum Network Methods ######################

    #region ############## Start Misc Methods ######################
    [String] ExecuteCurlMethod([String] $bashCommand) {
        if ( $this.SshSession -eq $null -or $this.SshSession.Connected -eq $false) { $this.OpenSshSession() }
        $sshCommand = (Invoke-SSHCommand $this.SshSession -Command $bashCommand)
        if ( $sshCommand.ExitStatus -ne 0) {
            $error = $sshCommand.Error
            throw [System.Exception] "Error executing the bash command(${bashCommand}): ${error}" 
        }             
        return -join $sshCommand.Output
    }

    [String] GetHostName() {
        if ( $this.SshSession -eq $null -or $this.SshSession.Connected -eq $false) { $this.OpenSshSession() }

        $bashCommand = "hostname"
        $sshCommand = (Invoke-SSHCommand $this.SshSession -Command $bashCommand)
        if ( $sshCommand.ExitStatus -ne 0) {
            $error = $sshCommand.Error
            throw [System.Exception] "Error executing hostname method: ${error}" 
        }     
        return $sshCommand.Output[0]
    }
    #endregion ############## End Misc Methods ######################

    [String] ToString() {
        $returnValue = $this.PublicHostName + ":" + $this.SshPortNumber
        return $returnValue
    }
}

Export-ModuleMember -Function New-NodeSshSession
Export-ModuleMember -Function New-ValidatorNode
Export-ModuleMember -Function Get-BigInteger