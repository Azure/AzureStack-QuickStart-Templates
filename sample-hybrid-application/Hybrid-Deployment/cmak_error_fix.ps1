#region Logins in and sets Resource group variable
Login-AzureRmAccount
$rg = Get-AzureRmResourceGroup | Select-Object ResourceGroupName
#endregion

#region Enables SSTP because 
$gateway = Get-AzureRmVirtualNetworkGateway -ResourceGroupName $rg.ResourceGroupName -Name Gateway
$gateway.VpnClientConfiguraiton.VpnClientProtocols
Set-AzureRmVirtualNetworkGateway -VirtualNetworkGateway $gateway -VpnClientProtocol "SSTP"
#endregion