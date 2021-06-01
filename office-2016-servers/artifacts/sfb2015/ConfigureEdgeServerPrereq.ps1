param
(
    [Parameter(Mandatory = $true)]
    [string] $HostName
)

function Delete-WinRMListener
{
    try
    {
        $config = Winrm enumerate winrm/config/listener
        foreach($conf in $config)
        {
            if($conf.Contains("HTTPS"))
            {
                Write-Verbose "HTTPS is already configured. Deleting the exisiting configuration."
    
                winrm delete winrm/config/Listener?Address=*+Transport=HTTPS
                break
            }
        }
    }
    catch
    {
        Write-Verbose -Verbose "Exception while deleting the listener: " + $_.Exception.Message
    }
}

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

function New-SelfSignedCert {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$SubjectName
    )
    PROCESS {
        $exists = (get-childitem "Cert:\localmachine\my" | ? {$_.Subject -eq "CN=$SubjectName"})
        if ($exists) {
            return $exists
        }
        $cryptographicProviderName = "Microsoft Base Cryptographic Provider v1.0";
        [int] $privateKeyLength = 1024;
        $sslServerOidString = "1.3.6.1.5.5.7.3.1";
        $sslClientOidString = "1.3.6.1.5.5.7.3.2";
        [int] $validityPeriodInYear = 5;

        $name = new-object -com "X509Enrollment.CX500DistinguishedName.1"
        $name.Encode("CN=" + $SubjectName, 0)

        $mesg = [System.String]::Format("Generating certificate with subject Name {0}", $subjectName);

        #Generate Key
        $key = new-object -com "X509Enrollment.CX509PrivateKey.1"
        $key.ProviderName = $cryptographicProviderName
        $key.KeySpec = 1 #X509KeySpec.XCN_AT_KEYEXCHANGE
        $key.Length = $privateKeyLength
        $key.MachineContext = 1
        $key.ExportPolicy = 0 #X509PrivateKeyExportFlags.XCN_NCRYPT_ALLOW_EXPORT_NONE
        $key.Create()

        #Configure Eku
        $serverauthoid = new-object -com "X509Enrollment.CObjectId.1"
        $serverauthoid.InitializeFromValue($sslServerOidString)
        $clientauthoid = new-object -com "X509Enrollment.CObjectId.1"
        $clientauthoid.InitializeFromValue($sslClientOidString)
        $ekuoids = new-object -com "X509Enrollment.CObjectIds.1"
        $ekuoids.add($serverauthoid)
        $ekuoids.add($clientauthoid)
        $ekuext = new-object -com "X509Enrollment.CX509ExtensionEnhancedKeyUsage.1"
        $ekuext.InitializeEncode($ekuoids)

        # Set the hash algorithm to sha512 instead of the default sha1
        $hashAlgorithmObject = New-Object -ComObject X509Enrollment.CObjectId
        $hashAlgorithmObject.InitializeFromAlgorithmName( $ObjectIdGroupId.XCN_CRYPT_HASH_ALG_OID_GROUP_ID, $ObjectIdPublicKeyFlags.XCN_CRYPT_OID_INFO_PUBKEY_ANY, $AlgorithmFlags.AlgorithmFlagsNone, "SHA512")

        #Request Cert
        $cert = new-object -com "X509Enrollment.CX509CertificateRequestCertificate.1"

        $cert.InitializeFromPrivateKey(2, $key, "")
        $cert.Subject = $name
        $cert.Issuer = $cert.Subject
        $cert.NotBefore = $(get-date).ToUniversalTime()
        $cert.NotAfter = $cert.NotBefore.AddYears($validityPeriodInYear);
        $cert.X509Extensions.Add($ekuext)
        $cert.HashAlgorithm = $hashAlgorithmObject
        $cert.Encode()

        $enrollment = new-object -com "X509Enrollment.CX509Enrollment.1"
        $enrollment.InitializeFromRequest($cert)
        $certdata = $enrollment.CreateRequest(0)
        $enrollment.InstallResponse(2, $certdata, 0, "")

        $count = 0
        while($count -le 10) {
            $cert = (get-childitem "Cert:\localmachine\my" | ? {$_.Subject -eq "CN=$SubjectName"})
            if($cert -eq $null) {
                Start-Sleep 1
                $count += 1
                continue
            }
            return $cert
        }
    }
}


function Configure-WinRMHttpsListener
{
    Param(
        [string] $HostName,
        [string] $port
    )

    # Delete the WinRM Https listener if it is already configured
    Delete-WinRMListener

    # Create a test certificate
    $cert = (Get-ChildItem cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=" + $hostname } | Select-Object -Last 1)
    $thumbprint = $cert.Thumbprint
    if(-not $thumbprint)
    {
        $cert = New-SelfSignedCert -SubjectName $HostName
        Export-Certificate -Type CERT -FilePath C:\winrm.cer -cert $cert
        $thumbprint = $cert.Thumbprint
    }
    elseif (-not $cert.PrivateKey)
    {
        # The private key is missing - could have been sysprepped
        # Delete the certificate
        Remove-Item Cert:\LocalMachine\My\$thumbprint -Force
        $cert = New-SelfSignedCert -SubjectName $HostName
        Export-Certificate -Type CERT -FilePath C:\winrm.cer -cert $cert
        $thumbprint = $cert.Thumbprint
    }

    $WinrmCreate= "winrm create --% winrm/config/Listener?Address=*+Transport=HTTPS @{Hostname=`"$hostName`";CertificateThumbprint=`"$thumbPrint`"}"
    invoke-expression $WinrmCreate
    winrm set winrm/config/service/auth '@{Basic="true"}'
}

function Add-FirewallException
{
    param([string] $port)

    # Delete an exisitng rule
    netsh advfirewall firewall delete rule name="Windows Remote Management (HTTPS-In)" dir=in protocol=TCP localport=$port

    # Add a new firewall rule
    netsh advfirewall firewall add rule name="Windows Remote Management (HTTPS-In)" dir=in action=allow protocol=TCP localport=$port
}


$winrmHttpsPort=5986
winrm set winrm/config '@{MaxEnvelopeSizekb = "8192"}'

# Configure https listener
Configure-WinRMHttpsListener $HostName $port

# Add firewall exception
Add-FirewallException -port $winrmHttpsPort

# Enable File and Printer sharing
Set-NetFirewallRule -Name 'FPS-SMB-In-TCP' -Enabled True

Import-CertToLocalMachineStore -Path C:\winrm.cer -StoreName "root"