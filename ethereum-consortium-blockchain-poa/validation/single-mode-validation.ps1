Param(
 [string]$resourceGroupName
)

$deploymentOutput = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName)[-1].Outputs
$failureMessage = "";

if ([string]::IsNullOrEmpty($deploymentOutput['admin_site'].Value))
{ 
    throw "Cannot locate admin_site in deployment output" 
}
# VSTS Powershell task is not compatible without "-UseBasicParsing"
$webpage = Invoke-WebRequest -Uri $deploymentOutput['admin_site'].Value -UseBasicParsing

$isRunning = $webpage.Content | Select-String -Pattern "Not Running"
if (![string]::IsNullOrEmpty($isRunning))
{ 
    $failureMessage +=  "At least one node is not running\n" 
}


# Verify that no nodes have peercount 0
# Peercounts are in the 2nd table, 2nd column
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

$table = @($html.all.tags("table"))[1]
$rows = @($table.rows)
foreach($row in $rows) {
    $cells = @($row.cells)
    $peercount = $cells[1].innerText
    if ($peercount -eq "0")
    { 
        $failureMessage +=  "At least one node has peercount 0\n" 
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

if (![string]::IsNullOrWhiteSpace($failureMessage))
{
    throw $failureMessage
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