param (
    [String]$resourceGroupName,
    [String]$adminPassword, # The account name can be looked up from the deployment parameters
    [String]$ethereumValidatorAdminPrivateKey, #The account number can be looked up from the deployment parameters
    [int]$remoteRpcPort = 8540
)

# Output the current PowerShell Version for informational purposes
Write-Output "PowerShell Version Installed"
$PSVersionTable.PSVersion
Write-Output "Node Version Installed"
node --version

Set-Location ${PSScriptRoot}

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

################################################
# Load misc modules
################################################

# Add path to the "./modules" folder to the search path in order to load custom modules
Write-Output "Current PS Module Paths: $env:PsModulePath"
$modulePath = "${PSScriptRoot}\modules"
if (-Not($env:PsModulePath.Contains($modulePath))) {
    $env:PsModulePath = "${env:PsModulePath};$modulePath"
    Write-Output "New PS Module Paths: $env:PsModulePath"
}

Import-Module ValidatorNode -Verbose -Force
Import-Module AzureStorage -Verbose -Force
Import-Module Pester -Verbose -Force

################################################
# Misc Functions
################################################


################################################
# Test Functions
################################################


#################################################################################################################
################################################ Start of Script ################################################
#################################################################################################################


################################################
# Get Deployment information
################################################
$deploymentGroup = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName)[-1]
if ($deploymentGroup -eq $null) {
    throw [System.Exception] "Could not load information about the Resource Group deployments"
}
$parameters = $deploymentGroup.Parameters
$numOfNodes = $parameters['numVLNodesRegion'].Value
$adminUsername = $parameters['adminUsername'].Value
$ethereamValidatorAccount = $parameters['ethereumAdminPublicKey'].Value
$omsDeployed = $parameters['omsDeploy'].Value

################################################
# Loop over each deployed region and node and add to the $nodeList
################################################

# Get public IPs in order to loop over each deployed region
$allPublicIps = Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroupName
$deployedPublicIps = $allPublicIps | Where-Object {$_.DnsSettings -ne $null}
if ($deployedPublicIps -eq $null -or $deployedPublicIps.Length -eq 0) {
    throw [System.Exception] "Cannot find any deployed public IP addresses"
}

$validatorNodeList = New-Object System.Collections.ArrayList

$PortToForwardToRpc = 4100

Try {
    # Loop over each deployed region
    $regionLoop = 0
    foreach ($deployedIP in $deployedPublicIps) {
        # Loop over each node in a region
        For ($nodeNumber = 0; $nodeNumber -lt $numOfNodes; $nodeNumber++) {
            $validatorNode = New-ValidatorNode `
                -port (4000 + $nodeNumber) `
                -remoteRpcPortNumber $remoteRpcPort `
                -portToForwardToRpc ($PortToForwardToRpc + $regionLoop + $nodeNumber) `
                -hostName $deployedIP.DnsSettings.Fqdn `
                -userName $adminUsername `
                -password $adminPassword
            $validatorNodeList.Add($validatorNode) > $null # Send to null to prevent output of index location printing to 
        }
        $regionLoop += 100
    }

    # Begin Tests
    test-AzureStorageFiles -resourceGroupName $resourceGroupName
    test-AllNodesHavePassphraseFile -resourceGroupName $resourceGroupName -validatorNodeList $validatorNodeList
    test-CompareFirstBlockHash -validatorNodeList $validatorNodeList
    test-CompareMultiBlockHashs -validatorNodeList $validatorNodeList
    #todo - Update to use initial administrator account
    #test-CanCreateContract -validatorNodeList $validatorNodeList -prefundPhrase $prefund_passphrase
    test-ValidatorContract -validatorNodeList $validatorNodeList -ethereumValidatorAdminPrivateKey $ethereumValidatorAdminPrivateKey
    test-AdminSiteTest -resourceGroupName $resourceGroupName -validatorNodeList $validatorNodeList
    test-OmsAgents -validatorNodeList $validatorNodeList -isOmsDeployed $omsDeployed
}
Catch {
    throw $_.Exception
    Break
}
Finally {
    foreach ($eachValidatorNode in $validatorNodeList) {
        $eachValidatorNode.CloseSshSession()
    }
}