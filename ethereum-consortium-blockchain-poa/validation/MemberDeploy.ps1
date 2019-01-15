
Param(
 [string] $resourceGroupName,
 [String] $leaderResourceGroupName,
 [String] $templateUri,
 [String] $baseUrl,
 [String] $location,
 [int] $consortiumMemberId,
 [String] $vmAdminPasswd,
 [Bool] $publicRPCEndpoint = $true,
 [BOOL] $deployUsingPublicIP = $false,
 [String] $ethereumAdminPublicKey = "0xf22210CD5930f0d194Bf38e52d80F3c02d5C4743"  
)

# Collect params from Leader
$outputs = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $leaderResourceGroupName)[-1].Outputs

$gatewayId = $outputs['consortium_member_gateway_id_region1'].Value
$consortiumData = $outputs['consortium_data_URL'].Value

# Collect OMS params from leader
$omsOutputs = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $leaderResourceGroupName -Name "deployOMS").Outputs
$omsWorkspaceId = $omsOutputs['workspaceId'].Value
$omsPrimarykey = $omsOutputs['primarySharedKey'].Value

$sharedKey = "1234"

Write-Output("======== Collected parameters from leader =============")
Write-Output("Gateway Id:" + $gatewayId)
Write-Output("Consortium data url:" + $consortiumData)

# Deploy Member
$joiningMemberParam = @{}
$joiningMemberParam.Add("isJoiningExistingNetwork",$TRUE)
$joiningMemberParam.Add("regionCount", 1)
$joiningMemberParam.Add("location_1", $location)
$joiningMemberParam.Add("authType", "password")
$joiningMemberParam.Add("adminUsername", "gethadmin")
$joiningMemberParam.Add("adminPassword", $vmAdminPasswd)
$joiningMemberParam.Add("adminSSHKey", $vmAdminPasswd)
$joiningMemberParam.Add("ethereumNetworkId", 10101010)
$joiningMemberParam.Add("consortiumMemberId", $consortiumMemberId)
$joiningMemberParam.Add("numVLNodesRegion", 2)
$joiningMemberParam.Add("vlNodeVMSize", "Standard_D1_v2")
$joiningMemberParam.Add("vlStorageAccountType", "Standard_LRS")
$joiningMemberParam.Add("consortiumDataURL", $consortiumData)
$joiningMemberParam.Add("consortiumMemberGatewayId", $gatewayId)
$joiningMemberParam.Add("connectionSharedKey", $sharedKey)
$joiningMemberParam.Add("baseUrl", $baseUrl)
$joiningMemberParam.Add("omsWorkspaceId", $omsWorkspaceId)
$joiningMemberParam.Add("omsPrimaryKey", $omsPrimaryKey)
$joiningMemberParam.Add("omsLocation", "eastus")
$joiningMemberParam.Add("ethereumAdminPublicKey", $ethereumAdminPublicKey)
$joiningMemberParam.Add("publicRPCEndpoint", $publicRPCEndpoint)
$joiningMemberParam.Add("enableSshAccess", $true)
$joiningMemberParam.Add("deployUsingPublicIP", $deployUsingPublicIP)


New-AzureRmResourceGroup -Name $resourceGroupName -Location $location
New-AzureRmResourceGroupDeployment -Name $resourceGroupName -ResourceGroupName $resourceGroupName -TemplateParameterObject $joiningMemberParam -TemplateUri $templateUri

#Usage: ./MemberDeploy.ps1 mbr_rg ldr_rg https://stgdev.blob.core.windows.net/devbox/ethereum-consortium-blockchain-network/common/mainTemplate.json https://stgdev.blob.core.windows.net/devbox/ethereum-consortium-blockchain-network/common eastus 3 mem

