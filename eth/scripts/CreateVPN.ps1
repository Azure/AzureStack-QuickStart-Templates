Param
(
    [Parameter(Mandatory = $true)]
    $VPNName,
    [Parameter(Mandatory = $true)]
    $RemoteIPAddress,
    [Parameter(Mandatory = $true)]
    $AddressSpace,
    [Parameter(Mandatory = $true)]
    $SharedKey
)

Install-WindowsFeature -Name Routing
Install-WindowsFeature -Name 'RSAT-RemoteAccess-PowerShell'
Install-RemoteAccess -VpnType VpnS2S
Start-Sleep -Seconds 10
Get-Service -Name RemoteAccess
$params = @{
    Name                             = $VPNName
    Protocol                         = 'IKEv2'
    Destination                      = $RemoteIPAddress
    AuthenticationMethod             = 'PSKOnly'
    SharedSecret                     = $SharedKey
    IPv4Subnet                       = '{0}:{1}' -f $AddressSpace,'200'
    AuthenticationTransformConstants = 'GCMAES256'
    CipherTransformConstants         = 'GCMAES256'
    DHGroup                          = 'Group2'
    EncryptionMethod                 = 'AES256' 
    IntegrityCheckMethod             = 'SHA256' 
    PfsGroup                         = 'PFS2048' 
    EnableQoS                        = 'Enabled' 
    NumberOfTries                    = 0  
}
Add-VpnS2SInterface @params -Persistent -CustomPolicy
Connect-VpnS2SInterface -Name $VPNName
