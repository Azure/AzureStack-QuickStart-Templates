param 
   ( 
        [Parameter(Mandatory)]
        [String]$masterVMNamePrefix,

        [Parameter(Mandatory)]
        [String]$agentVMNamePrefix,

        [Parameter(Mandatory)]
        [Int]$masterFirstAddr,

        [Parameter(Mandatory)]
        [Int]$agentFirstAddr,

        [Parameter(Mandatory)]
        [Int]$masterCount=1,

        [Parameter(Mandatory)]
        [Int]$agentCount=1,

		[Parameter(Mandatory)]
        [String]$baseSubnet
    ) 
    
    $hostsfilePath = "$env:SystemRoot\System32\drivers\etc\hosts"    

    For ($i=0; $i -lt $masterCount; $i++)
    {    
       $masterIp= "$baseSubnet$masterFirstAddr"
       $masterHostname = $masterVMNamePrefix + $i
       Write-Output "Adding $masterIp $masterHostname to /etc/hosts file"
       $masterIp + "`t`t" + $masterHostname | Out-File -encoding ASCII -append $hostsfilePath
       Write-Output "Completed"
       $masterFirstAddr++
    }
    For ($i=0; $i -lt $agentCount; $i++)
    {    
       $agentIp= $baseSubnet + $agentFirstAddr
       $agentHostname = $agentVMNamePrefix + $i
       Write-Output "Adding  $agentIp $agentHostname to /etc/hosts file"
       $agentIp + "`t`t" + $agentHostname | Out-File -encoding ASCII -append $hostsfilePath
       Write-Output "Completed"
       $agentFirstAddr++
    }
    

