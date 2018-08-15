<#
.SYNOPSIS
    Join the Virtual Networks of two consortium members together
.PARAMETER MyGatewayResourceId
    ResourceId of my Gateway
.PARAMETER OtherGatewayResourceId
    ResourceId of the Gateway I am trying to connect to
.PARAMETER ConnectionName
    Name of the Connection
.PARAMETER SharedKey
    Shared Key used by both Gateways to establish trust
#>
function CreateConnection(
	[string] $MyGatewayResourceId,
	[string] $OtherGatewayResourceId,
	[string] $ConnectionName,
	[string] $SharedKey
){
	Import-Module AzureRM.Network
	Import-Module AzureRM.Profile
	
	# $myGatewayResourceId tells me what subscription I am in, what ResourceGroup and the VNetGatewayName
	$splitValue = $MyGatewayResourceId.Split('/')
	$MySubscriptionid = $splitValue[2]
	$MyResourceGroup = $splitValue[4]
	$MyGatewayName = $splitValue[8]

	# $otherGatewayResourceid tells me what the subscription and VNet GatewayName are
	$OtherGatewayName = $OtherGatewayResourceId.Split('/')[8]

	$Subscription=Select-AzureRmSubscription -SubscriptionId $MySubscriptionid

	# create a PSVirtualNetworkGateway instance for the gateway I want to connect to
	$OtherGateway=New-Object Microsoft.Azure.Commands.Network.Models.PSVirtualNetworkGateway
	$OtherGateway.Name = $OtherGatewayName
	$OtherGateway.Id   = $OtherGatewayResourceId
	$OtherGateway.GatewayType = "Vpn"
	$OtherGateway.VpnType = "RouteBased"

	# get a PSVirtualNetworkGateway instance for my gateway
	$MyGateway = Get-AzureRmVirtualNetworkGateway -Name $MyGatewayName -ResourceGroupName $MyResourceGroup

	# create the connection
	New-AzureRmVirtualNetworkGatewayConnection -Name $ConnectionName -ResourceGroupName $MyResourceGroup -VirtualNetworkGateway1 $MyGateway -VirtualNetworkGateway2 $OtherGateway -Location $MyGateway.Location  -ConnectionType Vnet2Vnet -SharedKey $SharedKey -EnableBgp $True
}