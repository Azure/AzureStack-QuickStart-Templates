Param(
    [Parameter(Mandatory=$true)]
    [string]$AdminUser,
    [Parameter(Mandatory=$true)]
    [string]$adminPassword,
    [Parameter(Mandatory=$true)]
    [string]$DomainName,
    [Parameter(Mandatory=$true)]
    [string]$BaseResourceURI,
    [Parameter(Mandatory=$true)]
    [string]$isoName,
    [Parameter(Mandatory=$true)]
    [string]$AzCopyPackageName,
    [Parameter(Mandatory=$true)]
    [string]$modRewritePackageName,
    [Parameter(Mandatory=$true)]
    [string]$SqlServerPSName,
    [Parameter(Mandatory=$true)]
    [string]$SilverlightPackageName,
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
    [string]$cmuPackageName,
    [Parameter(Mandatory=$true)]
    [string]$WorkloadsZipName,
    [Parameter(Mandatory=$true)]
    [string]$FirstFE,
    [Parameter(Mandatory=$true)]
    [string]$SecondFE,
    [Parameter(Mandatory=$true)]
    [string]$ThirdFE,
    [Parameter(Mandatory=$true)]
    [string]$FirstEdge,
    [Parameter(Mandatory=$true)]
    [string]$SecondEdge,
    [Parameter(Mandatory=$true)]
    [string]$FirstEdgeInternal,
    [Parameter(Mandatory=$true)]
    [string]$FirstEdgeExternal,
    [Parameter(Mandatory=$true)]
    [string]$SecondEdgeInternal,
    [Parameter(Mandatory=$true)]
    [string]$SecondEdgeExternal,
    [Parameter(Mandatory=$true)]
    [string]$EdgePoolFQDN,
    [Parameter(Mandatory=$true)]
    [string]$FirstEdgePoolIP,
    [Parameter(Mandatory=$true)]
    [string]$SecondEdgePoolIP

)

ConvertTo-Json $PSBoundParameters | Set-Content C:\params.json

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"
# Maximum number of times to retry an operation
$maxRetries = 20

$isoURL = "{0}/{1}" -f @($BaseResourceURI, $isoName)
$AzCopyUri = "{0}/{1}" -f @($BaseResourceURI, $AzCopyPackageName)
$modRewriteURL = "{0}/{1}" -f @($BaseResourceURI, $modRewritePackageName)
$SqlServerPSUri = "{0}/{1}" -f @($BaseResourceURI, $SqlServerPSName)
$SilverlightURL = "{0}/{1}" -f @($BaseResourceURI, $SilverlightPackageName)
$cmuURL = "{0}/{1}" -f @($BaseResourceURI, $cmuPackageName)
$WorkloadsURL = "{0}/{1}" -f @($BaseResourceURI, $WorkloadsZipName)
$EdgeServersInfo = @(
    @{
        "HostName" = $FirstEdge;
        "internal" = $FirstEdgeInternal;
        "external" = $FirstEdgeExternal;
    },
    @{
        "HostName" = $SecondEdge;
        "internal" = $SecondEdgeInternal;
        "external" = $SecondEdgeExternal;
    }
)
$EdgePoolIPs = @($FirstEdgePoolIP, $SecondEdgePoolIP)
$scriptsFolder = ("{0}/Scripts" -f $env:SystemDrive)

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

$FirstFEHostName = $FirstFE.Replace(".{0}" -f $DomainName, '')
$SecondFEHostName = $SecondFE.Replace(".{0}" -f $DomainName, '')
$ThirdFEHostName = $ThirdFE.Replace(".{0}" -f $DomainName, '')

[array]$FEServersHostNames = @(
    $FirstFEHostName, $SecondFEHostName, $ThirdFEHostName
)

[array]$edgeServers = @($FirstEdge, $SecondEdge)
$allServers = $FEServersHostNames + $edgeServers

function Import-CertToLocalMachineStore {
    <#
    .SYNOPSIS
    Imports from file
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [Parameter(Mandatory=$true)]
        [string]$StoreName,
        [Parameter(Mandatory=$false)]
        [string]$Password
    )
    PROCESS {
        if($Password) {
            $securePassword = ConvertTo-SecureString -AsPlaintext -Force $Password
        }
        $rootName = "LocalMachine"

        # create a representation of the certificate file
        $certificate = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
        if($securePassword -eq $null)
        {
            $certificate.import($Path)
        }
        else
        {
            # https://msdn.microsoft.com/en-us/library/system.security.cryptography.x509certificates.x509keystorageflags(v=vs.110).aspx
            $certificate.import($Path, $securePassword, "MachineKeySet,PersistKeySet")
        }
        Write-Verbose ("Certificate thumbprint is {0}" -f $certificate.Thumbprint)
        $exists = (get-childitem ("Cert:\{0}\{1}" -f @($rootName, $StoreName)) | ? {$_.Thumbprint -eq $certificate.Thumbprint})
        Write-Verbose ("Exists is {0}" -f $exists)
        if ($exists) {
            return
        }
        # import into the store
        $store = new-object System.Security.Cryptography.X509Certificates.X509Store($StoreName, $rootName)
        $store.open("MaxAllowed")
        $store.add($certificate)
        $store.close()
    }
}

function Get-RandomString {
    <#
    .SYNOPSIS
    Returns a random string of characters, with a minimum length of 6, suitable for passwords
    .PARAMETER Length
    length of the random string.
    .PARAMETER Weak
    Use a smaller set of characters
    #>
    [CmdletBinding()]
    Param(
        [int]$Length=16,
        [switch]$Weak=$false
    )
    PROCESS {
        if($Length -lt 6) {
            $Length = 6
        }
        if(!$Weak) {
            $characters = 33..122
        }else {
            $characters = (48..57) + (65..90) + (97..122)
        }

        $special = @(33, 35, 37, 38, 43, 45, 46)
        $numeric = 48..57
        $upper = 65..90
        $lower = 97..122

        $passwd = [System.Collections.Generic.List[object]](New-object "System.Collections.Generic.List[object]")
        for($i=0; $i -lt $Length; $i++){
            $c = get-random -input $characters
            $passwd.Add([char]$c)
        }

        $passwd.Add([char](get-random -input $numeric))
        $passwd.Add([char](get-random -input $special))
        $passwd.Add([char](get-random -input $upper))
        $passwd.Add([char](get-random -input $lower))

        $Random = New-Object Random
        return [string]::join("",($passwd|Sort-Object {$Random.Next()}))
    }
}


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

function Export-CsCertificate {
    Param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory=$true)]
        [System.Security.SecureString]$encPassword,
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [string]$Use="AccessEdgeExternal"
    )

    $thumb = Invoke-Command -ComputerName . -Authentication Credssp -Credential $DomainCred -ScriptBlock {
        $crt = (Get-CsCertificate | ? {$_.Use -eq $Usessssss})[0]
        return $crt.Thumbprint
    }
    
    Write-Verbose "Thumbprint is: $thumb"

    Get-ChildItem -Path cert:\localMachine\my\$thumb | Export-PfxCertificate -FilePath $FilePath -Password $encPassword | Out-Null
    return $thumb
}

Write-Host 'Installing sql server powershell modules'
Install-SqlServerPowershellModule -URL $SqlServerPSUri

function Export-DomainRootCertificate {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$DomainName,
        [Parameter(Mandatory=$true)]
        [string]$ExportPath
    )

    $formated = ""
    foreach($i in $DomainName.split(".")){$formated += ', DC={0}' -f $i}

    $cert = ls Cert:\LocalMachine\Root\ | Where-Object {$_.Subject.contains($formated)}

    Export-Certificate -FilePath $ExportPath -Cert $cert[0]
}

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
Write-host "waiting for things to settle down"
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


# Enable CredSSP, and copy DSC resources on FrontEnd servers
Write-Host 'enable credSSP on FE'
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

    $allowed = @('WSMAN/*')
    $key = 'hklm:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'
    if (!(Test-Path $key)) {
        md $key
    }
    New-ItemProperty -Path $key -Name AllowFreshCredentials -Value 1 -PropertyType Dword -Force            
    $key = Join-Path $key 'AllowFreshCredentials'
    if (!(Test-Path $key)) {
        md $key
    }
    $i = 1
    $allowed |% {
        # Script does not take into account existing entries in this key
        New-ItemProperty -Path $key -Name $i -Value $_ -PropertyType String -Force
        $i++
    }
}

# Enable WinRM SSL with self signed certificate
Invoke-Command -ComputerName $Servers -Credential $DomainCred -ScriptBlock {
    $scriptsFolder = ("{0}/Scripts" -f $env:SystemDrive)
    if (!(Test-Path $scriptsFolder)) {
        Throw "Could not find scripts folder"
    }

    & $scriptsFolder\ConfigureWinrmSSL.ps1 -HostName (hostname) | Out-Null
}

# Import self signed certificates to root store
# This will allow us to run WinRM commands remotely, and DSC
# resources

# Wait for CredSSP to be available on the local machine
Write-Host 'wait for credssp'
Start-WaitForCredSSP -DomainName $DomainName -Credential $DomainCred

# Create SPN for all FE servers
Write-Host 'Creating SPN records for FE servers'
Invoke-Command -Credential $DomainCred -Authentication Credssp -ComputerName . -ScriptBlock {
    $DomainName = $using:DomainName
    foreach($srv in $using:FEServersHostNames) {
        Write-Verbose "Creating SPN for $srv"
        Invoke-Expression ("setspn -A WSMAN/$srv $srv")
        Invoke-Expression ("setspn -A WSMAN/$srv.$DomainName $srv")
    }
    Invoke-Expression ("klist purge")
}

Write-Host "import edge certs to root store"
Invoke-Command -Authentication Credssp -ComputerName . -Credential $DomainCred -ScriptBlock {
    $retry = 0
    while($true) {
        try {
            foreach ($srv in $using:allServers) {
                $destination = "{0}\{1}.cer" -f ($env:SystemDrive, $srv)
                cp -Force \\$srv\C$\winrm.cer $destination
            }
            break
        } catch {
            Write-Verbose "Got error: $_"
            if($retry -ge $using:maxRetries) {
                throw
            }
            $retry += 1
            Start-Sleep 10
        }
    }
}


foreach ($srv in $allServers) {
    $destination = "{0}\{1}.cer" -f ($env:SystemDrive, $srv)
    Import-CertToLocalMachineStore -StoreName root -Path $destination
}

# Enable CredSSP, and copy DSC resources on Edge servers
Write-Host "Enable Credssp on Edge"
Invoke-Command -computername $edgeServers -Authentication Basic -Credential $AdminCreds -UseSSL -ScriptBlock {
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

Write-Host "Grant SMB access"
try {
    # Grant access to FrontEnd server computer accounts on Share name
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
# Attempt to determine the correct SQL parameters
Write-Host "Get SQL params"
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


& $scriptsFolder\ConfigureWinrmSSL.ps1 -HostName (hostname) | Out-Null

$PrereqParams = @{
    AdminCreds = $AdminCreds
    DomainName = $DomainName
    isoURL = $isoURL
    modRewriteURL = $modRewriteURL
    silverlightURL = $silverlightURL
    SqlServerPSUri = $SqlServerPSUri
    AzCopyUri = $AzCopyURI
}

$retry = 0
# Install SFB prerequisites. This will install Sql server express and core
# SFB components on all servers. 
Write-Host ">>>>>>> InstallSfBFePrereq.ps1"
while($true) {
   try {
        Invoke-Command -Authentication Basic -UseSSL -Credential $AdminCreds -ComputerName $allServers -ScriptBlock {
            if((Test-Path "C:\DSC")){
                rm -Recurse -Force C:\DSC
            }
            $params = $using:PrereqParams
            & $using:scriptsFolder\InstallSfBFePrereq.ps1 @params
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
Write-Host ">>>>>>>>>>>>>>>>>>>>> DONE WITH InstallSfBFePrereq.ps1"

Invoke-Command -ComputerName . -Credential $DomainCred -ScriptBlock {
    try {
        Invoke-Expression ("klist purge")
        Start-Sleep 10
    } catch {
        $_
    }
}

# For some reason, SFB modules are not always picked up after installation, even when using CredSSP
# which in theory should start a new session, and apply the new PSModulePath environment variable.
# Copy the modules in the standard PSModulePath.
Invoke-Command -ComputerName $Servers -Authentication Credssp -Credential $DomainCred -ScriptBlock {
    cp -Recurse -Force "$env:ProgramFiles\Common Files\Skype for Business Server 2015\Modules\*" $env:ProgramFiles\WindowsPowerShell\Modules\
}

Invoke-Command -ComputerName $edgeServers -Authentication Basic -Credential $AdminCreds -UseSSL -ScriptBlock {
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
    EdgeServersInfo = $EdgeServersInfo
    EdgePoolIPs = $EdgePoolIPs
}

# Deploy the SFB topology.
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

# Export the SFB config. This will be imported on the edge servers
$configLocation = "{0}\{1}" -f ($env:SystemDrive, "SfbConfig.zip")
# generated string is not that weak, it just skips a few special characters
$clearPasswd = (Get-RandomString -Weak)
$encPassword = ConvertTo-SecureString -AsPlaintext -Force $clearPasswd

Invoke-Command -ComputerName . -Authentication Credssp -Credential $DomainCred -ScriptBlock {
    # Allow remote users to connect to SFB
    Set-CsExternalAccessPolicy -Identity Global -EnableOutsideAccess $true
    # export the SFB config
    if((Test-Path $using:configLocation)){
        rm -force $using:configLocation
    }
    Export-CsConfiguration -FileName $using:configLocation
}

# export root cert for AD. This is needed to validate
# certificates for FrontEnd servers
$rootCertPath = "{0}\rootCert.cer" -f $env:SystemDrive
if ((Test-Path $rootCertPath)){
    rm -Force $rootCertPath
}
Export-DomainRootCertificate -ExportPath $rootCertPath -DomainName $DomainName

Invoke-Command -ComputerName . -Authentication Credssp -Credential $DomainCred -ScriptBlock {
    # Copy config to edge servers
    $retry = 0
    while($true) {
        try {
            foreach ($srv in $using:edgeServers) {
                cp -Force $using:rootCertPath \\$srv\C$\rootCert.cer
                cp -Force $using:configLocation \\$srv\C$\SfbConfig.zip
            }
            break
        } catch {
            Write-Verbose "Got error: $_"
            if($retry -ge $using:maxRetries) {
                throw
            }
            $retry += 1
            Start-Sleep 5
        }
    }
}

# Import the AD root certificate into edge servers. This will allow the edge servers
# to trust certificates generated by ADCS
Invoke-Command -ComputerName $edgeServers -Authentication Basic -Credential $AdminCreds -UseSSL `
               -ScriptBlock ${Function:Import-CertToLocalMachineStore} `
               -ArgumentList $rootCertPath,"root"


$FeComponentsParams = @{
    AdminCreds = $AdminCreds
    DomainName = $DomainName
    CA = $CA
    cmuURL = $cmuURL
    Servers = $Servers
    EdgeServers = $edgeServers
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

$EdgeComponentsParams = @{
    AdminCreds = $AdminCreds
    cmuURL = $cmuURL
}

$retry = 0
while($true) {
   try {
        Write-Host ">>>>>>>>>>>>>>>>>>>>> STARTING deployEdgeComponents.ps1"
        Invoke-Command -Authentication Basic -UseSSL -Credential $AdminCreds -ComputerName $edgeServers -ScriptBlock {
            if((Test-Path "C:\DSC")){
                rm -Recurse -Force C:\DSC
            }
            $params = $using:EdgeComponentsParams
            & $using:scriptsFolder\deployEdgeComponents.ps1 @params
        }
        Write-Host ">>>>>>>>>>>>>>>>>>>>> DONE WITH deployEdgeComponents.ps1"
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

function New-EdgeServerCertificates {
    Param(
        [Parameter(Mandatory=$true)]
        [PSCredential]$Creds,
        [Parameter(Mandatory=$true)]
        [array]$Type,
        [Parameter(Mandatory=$true)]
        [string]$FriendlyName,
        [Parameter(Mandatory=$true)]
        [string]$ca,
        [Parameter(Mandatory=$true)]
        [bool]$PrivateKeyExportable,
        [Parameter(Mandatory=$true)]
        [string]$DomainName,
        [Parameter(Mandatory=$true)]
        [string]$computerfqdn,
        [Parameter(Mandatory=$true)]
        [bool]$New
        )
    
    $crt = ls cert:\localmachine\my | ? {$_.FriendlyName -eq $FriendlyName}
    if ($crt) {
        return $crt
    }
    
    $CertRequest = Invoke-command -Authentication Credssp -ComputerName . -Credential $Creds -ScriptBlock {
        $ref = Request-CsCertificate -ca $using:CA `
                                     -Type $using:Type `
                                     -FriendlyName $using:FriendlyName `
                                     -PrivateKeyExportable $true `
                                     -DomainName $using:DomainName `
                                     -ComputerFQDN $using:computerfqdn `
                                     -New:$using:New
        return $ref
    }
    
    return $CertRequest
}

$CertificateDomains = ("{0}.{1},{2}.{1},{3}" -f @(
                 "edge", $DomainName, "sipexternal",
                 ($EdgeServers -Join ",")))

$CertificateDomainsExternal = ("{0}.{1},{2}.{1},{3}" -f @(
                 "sipexternal", $DomainName, "edge",
                 ($EdgeServers -Join ",")))

$internalCrt = New-EdgeServerCertificates -New $true `
                           -Type "Internal" `
                           -FriendlyName "Edge server internal certificate" `
                           -CA $CA `
                           -PrivateKeyExportable $true `
                           -DomainName $CertificateDomains `
                           -ComputerFQDN $edgeServers[0] `
                           -Creds $DomainCred
$externalCrt = New-EdgeServerCertificates -New $true `
                           -Type "AccessEdgeExternal","DataEdgeExternal","AudioVideoAuthentication" `
                           -FriendlyName "Edge server external certificate" `
                           -CA $CA `
                           -PrivateKeyExportable $true `
                           -DomainName $CertificateDomainsExternal `
                           -ComputerFQDN $edgeServers[0] `
                           -Creds $DomainCred
                           
$extCrt = (ls ("cert:\localmachine\my\{0}" -f $externalCrt.thumbprint))
$intCrt = (ls ("cert:\localmachine\my\{0}" -f $internalCrt.thumbprint))

$serverCertExternalPath = "{0}\sfbEdgeExternalCert.pfx" -f $env:SystemDrive
Export-PfxCertificate -Cert $extCrt -FilePath $serverCertExternalPath -Password $encPassword | Out-Null
$csCertThumbprintExternal = $extCrt.thumbprint

$serverCertInternalPath = "{0}\sfbEdgeInternalCert.pfx" -f $env:SystemDrive
Export-PfxCertificate -Cert $intCrt -FilePath $serverCertInternalPath -Password $encPassword | Out-Null
$csCertThumbprintInternal = $intCrt.thumbprint


Invoke-Command -ComputerName . -Authentication Credssp -Credential $DomainCred -ScriptBlock {
    # Copy config to edge servers
    $retry = 0
    while($true) {
        try {
            foreach ($srv in $using:edgeServers) {
                cp -Force $using:serverCertExternalPath \\$srv\C$\sfbEdgeExternalCert.pfx
                cp -Force $using:serverCertInternalPath \\$srv\C$\sfbEdgeInternalCert.pfx
            }
            break
        } catch {
            Write-Verbose "Got error: $_"
            if($retry -ge $using:maxRetries) {
                throw
            }
            $retry += 1
            Start-Sleep 5
        }
    }
}

Invoke-Command -ComputerName $edgeServers -Authentication Basic -Credential $AdminCreds -UseSSL -ScriptBlock {
    $currentCerts = Get-CsCertificate -ErrorAction SilentlyContinue
    $shouldImportInternal = $false
    $shouldImportExternal = $false
    if (!$currentCerts) {
        $shouldImportExternal = $true
        $shouldImportInternal = $true
    } else {
        if ("Internal" -notin $currentCerts.Use) {
            $shouldImportInternal = $true
        }
        
        if ('AccessEdgeExternal' -notin $currentCerts.Use) {
            $shouldImportExternal = $true
        }
    }
    
    if ($shouldImportExternal) {
            Import-CsCertificate -Path $using:serverCertExternalPath -Password $using:clearPasswd
            Set-CsCertificate -Type "AccessEdgeExternal","DataEdgeExternal","AudioVideoAuthentication" -Thumbprint $using:csCertThumbprintExternal
    } else {
        Write-Verbose "External cert already imported"
    }
    
    if($shouldImportInternal) {
        Import-CsCertificate -Path $using:serverCertInternalPath -Password $using:clearPasswd
        Set-CsCertificate -Type "Internal" -Thumbprint $using:csCertThumbprintinternal
    } else {
        Write-Verbose "Internal cert already imported"
    }
}


$StartParams = @{
    AdminCreds = $DomainCred
    AuthenticationType = 'CredSSP'
}

$retry = 0
while($true) {
    try {
        if((Test-Path "C:\DSC")){
            rm -Recurse -Force C:\DSC
        }

        Write-Host ">>>>>>>>>>>>>>>>>>>>> Starting startSfbServices.ps1"
        Invoke-Command -Authentication CredSSP -Credential $DomainCred -ComputerName $Servers -ScriptBlock {
            $folder = $args[0]
            $params = $args[1]
            & $folder\startSfbServices.ps1 @params
        } -ArgumentList $scriptsFolder,$StartParams
        
        $StartParams["AuthenticationType"] = 'Basic'
        $StartParams["AdminCreds"] = $AdminCreds
        Invoke-Command -Authentication Basic -UseSSL -Credential $AdminCreds -ComputerName $edgeServers -ScriptBlock {
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

$EnableAdminParams = @{
    AdminCreds = $AdminCreds
    DomainName = $DomainName
}

$retry = 0
while($true) {
    try {
        if((Test-Path "C:\DSC")){
            rm -Recurse -Force C:\DSC
        }

        Write-Host ">>>>>>>>>>>>>>>>>>>>> Starting enableSfBAdmin.ps1"
        Invoke-Command -Authentication CredSSP -Credential $DomainCred -ComputerName . -ScriptBlock {
            whoami
            $folder = $args[0]
            $params = $args[1]
            & $folder\enableSfBAdmin.ps1 @params
        } -ArgumentList $scriptsFolder,$EnableAdminParams
        
        
        Write-Host ">>>>>>>>>>>>>>>>>>>>> DONE WITH enableSfBAdmin.ps1"
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

