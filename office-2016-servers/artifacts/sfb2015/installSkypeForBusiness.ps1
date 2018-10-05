Param(
    [Parameter(Mandatory=$true)]
    [string]$AdminUser,
    [Parameter(Mandatory=$true)]
    [string]$adminPassword,
    [Parameter(Mandatory=$true)]
    [string]$DomainName,
    [Parameter(Mandatory=$true)]
    [string]$isoURL,
    [Parameter(Mandatory=$true)]
    [string]$AzCopyURI,
    [Parameter(Mandatory=$true)]
    [string]$modRewriteURL,
    [Parameter(Mandatory=$true)]
    [string]$SqlServerPSUri,
    [Parameter(Mandatory=$true)]
    [string]$SilverlightURL,
    [Parameter(Mandatory=$true)]
    [string]$SqlServerFQDN,
    [Parameter(Mandatory=$true)]
    [string]$SqlAG,
    [Parameter(Mandatory=$true)]
    [string]$LBIPAddress,
    [Parameter(Mandatory=$true)]
    [string]$DNSserver,
    [Parameter(Mandatory=$true)]
    [string]$ShareFqdn,
    [Parameter(Mandatory=$true)]
    [string]$ShareName,
    [Parameter(Mandatory=$true)]
    [string]$CA,
    [Parameter(Mandatory=$true)]
    [string]$cmuURL,
    [Parameter(Mandatory=$true)]
    [string]$WorkloadsURL,
    [Parameter(Mandatory=$true)]
    [string]$FirstFE,
    [Parameter(Mandatory=$true)]
    [string]$SecondFE,
    [Parameter(Mandatory=$true)]
    [string]$ThirdFE
)

$ErrorActionPreference = "Stop"
# Maximum number of times to retry an operation
$maxRetries = 10

$secure = convertTo-securestring -AsPlaintext -force $adminPassword
[System.Management.Automation.PSCredential]$AdminCreds = New-Object System.Management.Automation.PSCredential ("${AdminUser}", $secure)
[System.Management.Automation.PSCredential]$DomainCred = New-Object System.Management.Automation.PSCredential ("${DomainName}\${AdminUser}", $secure)

if (!$FirstFE.EndsWith($DomainName)) {
    $FirstFE = "{0}.{1}" -f ($FirstFE, $DomainName)
}

if (!$SecondFE.EndsWith($DomainName)) {
    $SecondFE = "{0}.{1}" -f ($SecondFE, $DomainName)
}

if (!$ThirdFE.EndsWith($DomainName)) {
    $ThirdFE = "{0}.{1}" -f ($ThirdFE, $DomainName)
}

[array]$Servers = @(
    $FirstFE, $SecondFE, $ThirdFE
)

function Start-ExecuteWithRetry {
    <#
    .SYNOPSIS
    In some cases a command may fail several times before it succeeds, be it because of network outage, or a service
    not being ready yet, etc. This is a helper function to allow you to execute a function or binary a number of times
    before actually failing.

    Its important to note, that any powershell commandlet or native command can be executed using this function. The result
    of that command or powershell commandlet will be returned by this function.

    Only the last exception will be thrown, and will be logged with a log level of ERROR.
    .PARAMETER ScriptBlock
    The script block to run.
    .PARAMETER MaxRetryCount
    The number of retries before we throw an exception.
    .PARAMETER RetryInterval
    Number of seconds to sleep between retries.
    .PARAMETER ArgumentList
    Arguments to pass to your wrapped commandlet/command.

    .EXAMPLE
    # In the bellow example we retry 10 times and wait 10 seconds between retries before we
    # give up. If successful, $ret will contain the result of Get-NetAdapter. If it does not,
    # an exception is thrown. 
    $ret = Start-ExecuteWithRetry -ScriptBlock {
        Get-NetAdapter testuser
    } -MaxRetryCount 10 -RetryInterval 10
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Alias("Command")]
        [ScriptBlock]$ScriptBlock,
        [int]$MaxRetryCount=10,
        [int]$RetryInterval=3,
        [array]$ArgumentList=@()
    )
    PROCESS {
        $currentErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        $retryCount = 0
        while ($true) {
            try {
                $res = Invoke-Command -ScriptBlock $ScriptBlock `
                         -ArgumentList $ArgumentList
                $ErrorActionPreference = $currentErrorActionPreference
                return $res
            } catch [System.Exception] {
                $retryCount++
                if ($retryCount -gt $MaxRetryCount) {
                    $ErrorActionPreference = $currentErrorActionPreference
                    throw
                } else {
                    Write-Warning $_
                    Start-Sleep $RetryInterval
                }
            }
        }
    }
}

function Install-SqlServerPowershellModule {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$URL
    )

    $fileName = $URL.Split('/')[-1]
    $downloadPath = Join-Path $env:TMP $fileName
    Start-ExecuteWithRetry -ScriptBlock {
        $URL = $ArgumentList[0]
        $filePath = $ArgumentList[1]
        $client = [System.Net.WebClient](New-Object "System.Net.WebClient")
        $client.DownloadFile($URL, $filePath)
    } -ArgumentList $URL,$downloadPath

    $modulePath = "$env:ProgramFiles\WindowsPowerShell\Modules"
    if (!(test-path $modulePath)) {
        mkdir $modulePath | out-null
    }
    Expand-Archive -Force -Path $downloadPath -DestinationPath ("{0}\" -f $modulePath) | Out-Null
}

Install-SqlServerPowershellModule -URL $SqlServerPSUri

function Start-WaitForCredSSP {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$DomainName,
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$Credential,
        [int]$RetryInterval=5
    )

    $LocalNode = (Get-WmiObject Win32_ComputerSystem).Name
    Invoke-Expression ("setspn -A WSMAN/$LocalNode $LocalNode")
    Invoke-Expression ("setspn -A WSMAN/$LocalNode.$DomainName $LocalNode")
    Invoke-Expression ("klist purge")

    $CredSSPOK = $false

    Write-Warning "Starting WaitForCredSSP"

    While (-not ($CredSSPOK)){
        start-sleep $RetryInterval
        Write-Warning "Attempting to authenticate using CredSSP"
        $Session = New-PSSession -authentication CredSSP -Credential $Credential -ErrorAction SilentlyContinue
        If ($Session) {
            $CredSSPOK = Invoke-Command -ErrorAction SilentlyContinue -Session $Session -ScriptBlock{
                return "ok"
            }
            Remove-PSSession -Session $Session -ErrorAction SilentlyContinue
        }
    }
    Write-Warning "Successfully authenticated using CredSSP"
}

# Wait for things to settle down
Start-ExecuteWithRetry -ScriptBlock {
    $FirstFE = $ArgumentList[0]
    $SecondFE = $ArgumentList[1]
    $ThirdFE = $ArgumentList[2]
    $DomainCred = $ArgumentList[3]
    $DomainName = $ArgumentList[4]

    Install-WindowsFeature -Name RSAT-ADDS -IncludeAllSubFeature | Out-Null
    Get-ADComputer -Identity $FirstFE.Replace(".{0}" -f $DomainName, "") -Credential $DomainCred | Out-Null
    Get-ADComputer -Identity $SecondFE.Replace(".{0}" -f $DomainName, "") -Credential $DomainCred | Out-Null
    Get-ADComputer -Identity $ThirdFE.Replace(".{0}" -f $DomainName, "") -Credential $DomainCred | Out-Null
} -MaxRetryCount 30 -RetryInterval 10 -ArgumentList $FirstFE,$SecondFE,$ThirdFE,$DomainCred,$DomainName

Invoke-Command -ComputerName $Servers -Credential $DomainCred -ScriptBlock {
    Enable-WSManCredSSP -Role Server -Force | Out-Null
    Enable-WSManCredSSP -Role Client -DelegateComputer '*' -Force | Out-Null
    $src = $using:WorkloadsURL
    $workLoadsFile = ("{0}\{1}" -f @($env:SystemDrive, $src.Split('/')[-1]))
    #Write-Host $src
    #Write-Host $workLoadsFile
    wget -UseBasicParsing -Uri $src -OutFile $workLoadsFile
    #$cl = [System.Net.WebClient](New-Object "System.Net.WebClient")
    #$cl.DownloadFile($src, $workLoadsFile)

    $tmpFolder = Join-Path $env:TMP ([guid]::NewGuid().Guid)
    if(!(Test-Path $tmpFolder)) {
        mkdir $tmpFolder | Out-Null
    }

    $modulesPath = ("{0}/Program Files/WindowsPowerShell/Modules" -f $env:SystemDrive)

    Expand-Archive -Path $workLoadsFile -DestinationPath $tmpFolder
    $folderContents = ls $tmpFolder
    foreach($item in $folderContents){
        $fullPath = Join-Path $tmpFolder $item
        if ((Get-Item $fullPath) -is [System.IO.DirectoryInfo]) {
            cp -Recurse -Force $fullPath $modulesPath
        }
    }

    $scriptsFolder = ("{0}/Scripts" -f $env:SystemDrive)
    if (!(Test-Path $scriptsFolder)) {
        mkdir $scriptsFolder | Out-Null
    }

    cp -Force "$tmpFolder/*.ps1" $scriptsFolder
}


Start-WaitForCredSSP -DomainName $DomainName -Credential $DomainCred


try {
    # Grant access to computer accounts on Share name
    Invoke-Command -ComputerName $ShareFqdn -Credential $DomainCred -ScriptBlock {
        $first = $using:FirstFE
        $second = $using:SecondFE
        $third = $using:ThirdFE
        $domainName = $using:DomainName

        $FirstFE = ("{0}$" -f $first.Replace(".{0}" -f $domainName, ""))
        $SecondFE = ("{0}$" -f $second.Replace(".{0}" -f $domainName, ""))
        $ThirdFE = ("{0}$" -f $third.Replace(".{0}" -f $domainName, ""))

        Grant-SmbShareAccess -Name data -AccountName $FirstFE,$SecondFE,$ThirdFE -AccessRight Full -Confirm:$false
        Set-SmbPathAcl -ShareName $using:ShareName
    }
} catch {
    Write-Warning "Failed to grant SMB share access: $_"    
}

$retry = 0
while($true) {
    try{
        Write-Verbose "getting SQL parameters"
        $sqlParams = Invoke-Command -Authentication Credssp -ComputerName . -Credential $DomainCred -ScriptBlock {
            $SqlServerFQDN = $using:SqlServerFQDN
            $AlwaysOnAG = $using:SqlAG
            Write-Host (">>>>>>>>>>>>>>>Before function definition {0} -- {1}" -f @($SqlServerFQDN,  $AlwaysOnAG))
            function Get-SQLParameters {
                Param(
                    [Parameter(Mandatory=$true)]
                    [string]$SqlServerFQDN,
                    [Parameter(Mandatory=$true)]
                    [string]$AlwaysOnAG
                )

                Import-Module SqlServer
                $domain = (gcim win32_computersystem).Domain
                $Ag = ls sqlserver://sql/$SqlServerFQDN/DEFAULT/AvailabilityGroups/ | Where-Object {$_.Name -eq $AlwaysOnAG}
                $PrimarySQLServerFQDN = "{0}.{1}" -f @($Ag.PrimaryReplicaServerName, $domain)
                $Listeners = ls sqlserver://sql/$SqlServerFQDN/DEFAULT/AvailabilityGroups/$AlwaysOnAG/AvailabilityGroupListeners
                $AogListenerFQDN = "{0}.{1}" -f @($Listeners[0].Name, $domain)
                $AvailabilityReplicas = ls sqlserver://sql/$SqlServerFQDN/DEFAULT/AvailabilityGroups/$AlwaysOnAG/AvailabilityReplicas | Where-Object {$_.Name -ne $Ag.PrimaryReplicaServerName}
                $SecondarySqlServerFQDN = "{0}.{1}" -f @($AvailabilityReplicas[0].Name, $domain)

                return @{
                    "PrimarySQLServerFQDN" = $PrimarySQLServerFQDN
                    "AogListenerFQDN" = $AogListenerFQDN
                    "SecondarySqlServerFQDN" = $SecondarySqlServerFQDN
                }
            }

            return (Get-SQLParameters -SqlServerFQDN $SqlServerFQDN -AlwaysOnAG $AlwaysOnAG)
        }
        break
    } catch {
        Write-Verbose "Got error: $_"
        if($retry -ge $maxRetries) {
            throw
        }
        $retry += 1
        Start-Sleep 5
    }
}


$scriptsFolder = ("{0}/Scripts" -f $env:SystemDrive)

$PrereqParams = @{
    AdminCreds = $AdminCreds
    DomainName = $DomainName
    isoURL = $isoURL
    modRewriteURL = $modRewriteURL
    silverlightURL = $silverlightURL
    SqlServerPSUri = $SqlServerPSUri
    AzCopyUri = $AzCopyURI
    Servers = $Servers
}

$retry = 0
while($true) {
    try {
        Write-Verbose 'Starting DSC'
        if((Test-Path "C:\DSC")){
            rm -Recurse -Force C:\DSC
        }
        Invoke-Command -ComputerName . -Authentication Credssp -Credential $DomainCred -ScriptBlock {
            $folder = $args[0]
            $params = $args[1]
            Write-Host $params["AzCopyUri"]
            & $folder\InstallSfBFePrereq.ps1 @params
        } -ArgumentList $scriptsFolder,$PrereqParams
        Write-Host ">>>>>>>>>>>>>>>>>>>>> DONE WITH InstallSfBFePrereq.ps1"
        break
    } catch {
        Write-Verbose "Got error: $_"
        if($retry -ge $maxRetries) {
            throw
        }
        $retry += 1
        Start-Sleep 5
    }
}


Invoke-Command -ComputerName $Servers -Authentication Credssp -Credential $DomainCred -ScriptBlock {
    cp -Recurse -Force "$env:ProgramFiles\Common Files\Skype for Business Server 2015\Modules\*" $env:ProgramFiles\WindowsPowerShell\Modules\
}

$PrimarySqlServerFQDN = $sqlParams["PrimarySQLServerFQDN"]
$SecondarySqlServerFQDN = $sqlParams["SecondarySqlServerFQDN"]
$SqlAOListenerFQDN = $sqlParams["AogListenerFQDN"]

$TopologyParams = @{
    AdminCreds = $AdminCreds
    DomainName = $DomainName
    PrimarySqlServerFQDN = $PrimarySqlServerFQDN
    SecondarySqlServerFQDN = $SecondarySqlServerFQDN
    SqlAOListenerFQDN = $SqlAOListenerFQDN
    SqlAG = $SqlAG
    LBIPAddress = $LBIPAddress
    DNSserver = $DNSserver
    Servers = $Servers
    ShareFqdn = $ShareFqdn
    ShareName = $ShareName
}

$retry = 0
while($true) {
    try {
        if((Test-Path "C:\DSC")){
            rm -Recurse -Force C:\DSC
        }

        Write-Host ">>>>>>>>>>>>>>>>>>>>> STARTING deploySfBTopology.ps1"
        Invoke-Command -ComputerName . -Authentication Credssp -Credential $DomainCred -ScriptBlock {
            $folder = $args[0]
            $params = $args[1]
            & $folder\deploySfBTopology.ps1 @params
        } -ArgumentList $scriptsFolder,$TopologyParams

        Write-Host ">>>>>>>>>>>>>>>>>>>>> DONE WITH deploySfBTopology.ps1"
        break
    } catch {
        Write-Verbose "Got error: $_"
        if($retry -ge $maxRetries) {
            throw
        }
        $retry += 1
        Start-Sleep 5
    }
}

$FeComponentsParams = @{
    AdminCreds = $AdminCreds
    DomainName = $DomainName
    CA = $CA
    cmuURL = $cmuURL
    Servers = $Servers
}

$retry = 0
while($true) {
    try {
        if((Test-Path "C:\DSC")){
            rm -Recurse -Force C:\DSC
        }

        Write-Host ">>>>>>>>>>>>>>>>>>>>> STARTING deployFrontEndComponents.ps1"
        Invoke-Command -ComputerName . -Authentication Credssp -Credential $DomainCred -ScriptBlock {
            $folder = $args[0]
            $params = $args[1]
            & $folder\deployFrontEndComponents.ps1 @params
        } -ArgumentList $scriptsFolder,$FeComponentsParams
        #} -ArgumentList $FeComponentsParams,$scriptsFolder -MaxRetryCount 3 -RetryInterval 10
        Write-Host ">>>>>>>>>>>>>>>>>>>>> DONE WITH deployFrontEndComponents.ps1"
        break
    } catch {
        Write-Verbose "Got error: $_"
        if($retry -ge $maxRetries) {
            throw
        }
        $retry += 1
        Start-Sleep 5
    }
}

$StartParams = @{
    AdminCreds = $AdminCreds
    DomainName = $DomainName
    Servers = $Servers
}

$retry = 0
while($true) {
    try {
        if((Test-Path "C:\DSC")){
            rm -Recurse -Force C:\DSC
        }

        Write-Host ">>>>>>>>>>>>>>>>>>>>> Starting startSfbServices.ps1"
        Invoke-Command -ComputerName . -Authentication Credssp -Credential $DomainCred -ScriptBlock {
            $folder = $args[0]
            $params = $args[1]
            & $folder\startSfbServices.ps1 @params
        } -ArgumentList $scriptsFolder,$StartParams
        Write-Host ">>>>>>>>>>>>>>>>>>>>> DONE WITH startSfbServices.ps1"
        break
    } catch {
        Write-Verbose "Got error: $_"
        if($retry -ge $maxRetries) {
            throw
        }
        $retry += 1
        Start-Sleep 5
    }
}