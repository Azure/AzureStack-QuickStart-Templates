$global:blockPadding = 10
function Get-NodeHostNameFromBlob() {
    [OutputType([PSCustomObject])]
    Param([Parameter(Mandatory = $true)][String] $resourceGroupName)
    $blobs = (Get-AzureBlobFileContents -resourceGroupName $resourceGroupName -fileName "passphrase-*.json").TrimEnd("`n")
    $hosts = New-Object System.Collections.ArrayList
    foreach ($blob in $blobs) {
        $hosts.add(($blob | ConvertFrom-Json).hostname) > $null
    }
    return $hosts
}

function Get-ParseAdminTableHtmlToObject() {
    [OutputType([PSCustomObject])]
    Param([Parameter(Mandatory = $true)][String] $htmlContent)

    $isRunning = $htmlContent | Select-String -Pattern "Not Running"
    if (![string]::IsNullOrEmpty($isRunning)) {
        throw "At least one node is not running\n"
    }

    $html = New-Object -ComObject "HTMLFile";
    try {
        # This works in PowerShell with Office installed
        $html.IHTMLDocument2_write($webpage.RawContent)
    }
    catch {
        # This works when Office is not installed    
        $src = [System.Text.Encoding]::Unicode.GetBytes($webpage.RawContent)
        $html.write($src)
    }    $table = @($html.getElementById("nodesTable"))[0];
    $rows = @($table.rows)

    $adminNodeList = New-Object System.Collections.ArrayList
    foreach ($row in $rows) {
        $object = @{}
        $cells = @($row.cells)
        $nodeHostHeader = $cells[0].innerText -eq "Node Hostname"
        $PeerCountHeader = $cells[1].innerText -eq "Peer Count"
        $LatestBlockHeader = $cells[2].innerText -eq "Latest Block Number"

        if (!$nodeHostHeader -OR !$PeerCountHeader -OR !$LatestBlockHeader) {
            # Host Name
            $object.HostName = $cells[0].innerText
            # Peer
            $object.PeerCount = [convert]::ToInt32($cells[1].innerText, 10)
            # Last Block Number
            $object.LatestBlockNumber = [convert]::ToInt32($cells[2].innerText, 10)     
            $adminNodeList.add($object) > $null
        }
    }
    return $adminNodeList
}

function test-AdminSiteTest {
    Param(
        [Parameter(Mandatory = $true)][String] $resourceGroupName,
        [Parameter(Mandatory = $true)][System.Collections.ArrayList] $validatorNodeList)

    Write-Host "Starting Test - Admin Site Testing"

    # Assert all node list (node host name, peer count, and approximately latest block number) compares against the blob container
    # get all blob with blob prefix 
    # Parse host name 
    Describe "Verify All Node List on The Admin Site " { 
        It "Assert all node info on admin site " {
            # Get information about all the blobs in the storage account
            $hostNames = Get-NodeHostNameFromBlob($resourceGroupName)    
            $bashCommand = "curl http://localhost:3000 | sed $'s/\r//'"

            # Assert Count of Hosts and Validator Node Count
            $hostNames.count | Should Be $validatorNodeList.Count
            $nodeCompareTo = $null
            for ($idx = 0; $idx -lt $validatorNodeList.Count; $idx++) {
                $content = $validatorNodeList[$idx].ExecuteCurlMethod($bashCommand)
                $nodeInfo = Get-ParseAdminTableHtmlToObject -htmlContent $content 
                if ($idx -eq 0) {           
                    $nodeCompareTo = $nodeInfo
                    continue
                }
                else {
                    $nodeInfo.count | should be $nodeCompareTo.count
                    for ($nodeIdx = 0; $nodeIdx -lt $nodeInfo.count; $nodeIdx++) {
                        $nodeInfo[$nodeIdx].HostName | Should -Be $nodeCompareTo[$nodeIdx].HostName
                        $nodeInfo[$nodeIdx].PeerCount | Should -Be $nodeCompareTo[$nodeIdx].PeerCount
                        $min = $nodeCompareTo[$nodeIdx].LatestBlockNumber - ($global:blockPadding / 2)
                        $max = $min + $global:blockPadding 
                        $nodeInfo[$nodeIdx].LatestBlockNumber | Should -beIn ($min .. $max)
                    }
                }
            }
        }        
    }  
}

Export-ModuleMember -Function test-AdminSiteTest 