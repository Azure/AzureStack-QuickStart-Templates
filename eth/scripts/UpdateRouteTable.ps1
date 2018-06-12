Param
(
    [Parameter(Mandatory = $true)]
    $RouteTableName,
    [Parameter(Mandatory = $true)]
    $PrivateIpAddress,
    [Parameter(Mandatory = $true)]
    $RemoteAddressSpace
)

Import-Module AzureRM.Network

$routeTable = Get-AzureRmRouteTable -Name $RouteTableName 
Add-AzureRmRouteConfig -Name "WinNVARoute" -AddressPrefix $RemoteAddressSpace -NextHopType VirtualAppliance -NextHopIpAddress $PrivateIpAddress -RouteTable $routeTable
Set-AzureRmRouteTable -RouteTable $routeTable