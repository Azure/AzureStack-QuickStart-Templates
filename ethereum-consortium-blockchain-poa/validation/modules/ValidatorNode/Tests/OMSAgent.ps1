
function test-OmsAgents{
    Param(
        [Parameter(Mandatory = $true)][System.Collections.ArrayList] $validatorNodeList,
        [Parameter(Mandatory = $true)][bool] $isOmsDeployed
        )
    foreach ($node in $validatorNodeList){
        test-LogFiles -node $node
        if($isOmsDeployed){
            test-OmsAgent -node $node
        }
    }
}
function test-ValidateLogHasContent{
    Param(
    [Parameter(Mandatory = $true)] $node,
    [Parameter(Mandatory = $true)][string] $logFile
    )
    # First check existance
    $node.ExecuteCurlMethod("ls $logfile") | Should Be $logFile
    # Then check contents
    $node.ExecuteCurlMethod("cat $logfile").length | Should BeGreaterThan 0
}

function test-BashCommandShouldBeGreaterThan{
    Param(
        [Parameter(Mandatory = $true)] $node,
        [Parameter(Mandatory = $true)][string] $bashCommand,
        [Parameter(Mandatory = $true)]$expectValue
        )
    $result = $node.ExecuteCurlMethod($bashCommand)
    $result | Should BeGreaterThan $expectValue 
}

function test-LogFiles{
    Param(
    [Parameter(Mandatory = $true)][PSCustomObject] $node
    )

    $parityLogFilePath = "/var/log/parity/parity.log"
    $adminLogFilePath = "/var/log/adminsite/etheradmin.log"
    $statsLogFilePath = "/var/log/stats/ethstat.log"
    $deploymentLogFilePath = "/var/log/deployment/config.log"
   
    Describe "Verify All Node Log Files : $node" { 
        It "Assert Deployment Log File Path"{
            test-ValidateLogHasContent -node $node -logFile $deploymentLogFilePath
        }

        It "Assert Parity Log File Path" {
            test-ValidateLogHasContent -node $node -logFile $parityLogFilePath
        }

        It "Assert Admin Site Log File Path" {
            test-ValidateLogHasContent -node $node -logFile $adminLogFilePath
        }

        It "Assert Stats Log File Path" {
            test-ValidateLogHasContent -node $node -logFile $statsLogFilePath
        }
    }
}

function test-OmsAgent{
    Param(
    [Parameter(Mandatory = $true)][PSCustomObject] $node
    )
    Describe "Verify OMS agent : $node" { 
        It "Verify OMS agent Running only if OMS deployed"{
            test-BashCommandShouldBeGreaterThan -node $node -bashCommand "ps aux | grep -c omiagent" -expectValue 1 # Verify the oms agent running
        }
    }
}

Export-ModuleMember -Function test-OmsAgents
