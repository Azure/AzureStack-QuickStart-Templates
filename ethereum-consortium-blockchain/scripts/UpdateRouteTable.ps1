Param
(
    [Parameter(Mandatory = $true)]
    $RouteTableName,
    [Parameter(Mandatory = $true)]
    $NicResourceId,
    [Parameter(Mandatory = $true)]
    $RemoteAddressSpace
)

Import-Module AzureRM.Network

$splited = $NicResourceId.Split('/')
$resourceGroup = $splited[4]
$nicName = $splited[8]
$routeTable = Get-AzureRmRouteTable -Name $RouteTableName -ResourceGroupName $resourceGroup
$nic = Get-AzureRmNetworkInterface -Name $nicname -ResourceGroupName $resourceGroup
$privateIpAddress = $nic.IpConfigurations[0].PrivateIpAddress
Add-AzureRmRouteConfig -Name "WinNVARoute" -AddressPrefix $RemoteAddressSpace -NextHopType VirtualAppliance -NextHopIpAddress $privateIpAddress -RouteTable $routeTable
Set-AzureRmRouteTable -RouteTable $routeTable