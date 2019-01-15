Param(
 [string] $resourceGroupName,
 [Int32] $preValidationSleepSec=0,
 [Int32] $peerCountGreaterThan=0,
 [string] $deploymentMode="Member"
)


# Wait for vnet connection to be established and nodes to peer before validating deployment
Start-Sleep -s $PreValidationSleepSec;

# Check if vnet connection is successful
# if ($deploymentMode -eq "Member") {
#     $vnetConnection = Get-AzureRmVirtualNetworkGatewayConnection -Name "conn-to-other-gateway" -ResourceGroupName $resourceGroupName
#     $isConnected = $vnetConnection.ConnectionStatus -eq  "Connected"

#     if ($isConnected -eq $FALSE)
#     { 
#         throw "Unable to connect to leader deployment gateway" 
#     }
# }

$deploymentOutput = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName)[-1].Outputs
$failureMessage = "";
if ([string]::IsNullOrEmpty($deploymentOutput['admin_site'].Value))
{ 
    throw "Cannot locate admin_site in deployment output" 
}
# VSTS Powershell task is not compatible without "-UseBasicParsing"
$webpage = Invoke-WebRequest -Uri $deploymentOutput['admin_site'].Value -UseBasicParsing


# If some nodes are not running , wait a bit
$isRunning = $webpage.Content | Select-String -Pattern "Not Running"
$numAttemps = 0

Do

{

  Start-Sleep -s 10
  Write-Output "waiting nodes to pair ..."
  $isRunning = $webpage.Content | Select-String -Pattern "Not Running"
  $numAttemps = $numAttemps + 1

} While (![string]::IsNullOrEmpty($isRunning) -and $numAttemps -le 10)

if (![string]::IsNullOrEmpty($isRunning))
{ 
    throw "At least one node is not running\n" 
}


# Verify that no nodes have peercount 0
# Peercounts are in the 2nd table, 3rd column
$html = New-Object -ComObject "HTMLFile";

try {
    # This works in PowerShell with Office installed
    $html.IHTMLDocument2_write($webpage.RawContent)
}
catch {
    # This works when Office is not installed    
    $src = [System.Text.Encoding]::Unicode.GetBytes($webpage.RawContent)
    $html.write($src)
}

$table = @($html.all.tags("table"))[4]
$rows = @($table.rows)

foreach($row in $rows) {
    $cells = @($row.cells)
    $header= $cells[1].innerText -eq "Peer Count"
    if (!$header) {
        $peercount = [convert]::ToInt32($cells[1].innerText, 10)
        if ($peercount -le 0)
        { 
            $failureMessage +=  "Expected more than "+$PeerCountGreaterThan+" peers, found "+$peercount+" peers\n"
        }
    }
}

# Verify that the JSON RPC endpoint is responsive
if ([string]::IsNullOrEmpty($deploymentOutput['ethereum_rpc_endpoint'].Value))
{ 
    throw "Cannot locate ethereum_rpc_endpoint in deployment output" 
}

$url = $deploymentOutput['ethereum_rpc_endpoint'].Value
$command = '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":83}'

$bytes = [System.Text.Encoding]::ASCII.GetBytes($command)
$web = [System.Net.WebRequest]::Create($url)
$web.Method = "POST"
$web.ContentLength = $bytes.Length
$web.ContentType = "application/json"
$stream = $web.GetRequestStream()
$stream.Write($bytes,0,$bytes.Length)
$stream.close()

$reader = New-Object System.IO.Streamreader -ArgumentList $web.GetResponse().GetResponseStream()
$rpcResponse = $reader.ReadToEnd() | ConvertFrom-Json 
$reader.Close()

# Parity response is in the format {"jsonrpc":"2.0","result":"0x36","id":83}
$blockNumber=$rpcResponse.result
Write-Output("Block #:" + $blockNumber)

if ([string]::IsNullOrEmpty($blockNumber))
{ 
    $failureMessage += "JSON RPC not responding\n" 
}

# Test for correct network info response
$webpage = Invoke-WebRequest -Uri "$($deploymentOutput['admin_site'].Value)/networkinfo" -UseBasicParsing
$networkInfo = $webpage.Content | ConvertFrom-Json
if (![string]::IsNullOrWhiteSpace($networkInfo.errorMessage))
{
    $failureMessage += "Error retreiving network info: $($networkInfo.errorMessage) \n"; 
}
if ([string]::IsNullOrWhiteSpace($networkInfo.valSetContract) -or
    [string]::IsNullOrWhiteSpace($networkInfo.adminContract) -or
    [string]::IsNullOrWhiteSpace($networkInfo.adminContractABI) -or
    [string]::IsNullOrWhiteSpace($networkInfo.paritySpec))
{
    $failureMessage += "Missing expected network info: $($networkInfo) \n"; 
}

if (![string]::IsNullOrWhiteSpace($failureMessage))
{
    throw $failureMessage
}