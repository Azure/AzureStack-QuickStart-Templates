
Param(
 [string] $resourceGroupName,
 [String] $templateUri,
 [String] $baseUrl,
 [String] $location,
 [int] $consortiumMemberId,
 [String] $vmAdminPasswd,
 [String] $omsWorkspaceId,
 [String] $omsPrimarykey,
 [Bool] $publicRPCEndpoint = $true,
 [String] $ethereumAdminPublicKey = "0xf22210CD5930f0d194Bf38e52d80F3c02d5C4743"
)

# Deploy Leader
$param = @{}
$param.Add("isJoiningExistingNetwork",$false)
$param.Add("deployUsingPublicIP",$true)
$param.Add("regionCount", 1)
$param.Add("location_1", $location)
$param.Add("authType", "password")
$param.Add("adminUsername", "gethadmin")
$param.Add("adminPassword", $vmAdminPasswd)
$param.Add("adminSSHKey", $vmAdminPasswd)
$param.Add("ethereumNetworkId", 10101010)
$param.Add("consortiumMemberId", $consortiumMemberId)
$param.Add("numVLNodesRegion", 2)
$param.Add("vlNodeVMSize", "Standard_D1_v2")
$param.Add("vlStorageAccountType", "Standard_LRS")
$param.Add("baseUrl",$baseUrl)
$param.Add("omsWorkspaceId", $omsWorkspaceId)
$param.Add("omsPrimaryKey", $omsPrimarykey)
$param.Add("omsLocation", $location)
$param.Add("ethereumAdminPublicKey", $ethereumAdminPublicKey )
$param.Add("publicRPCEndpoint", $publicRPCEndpoint)
$param.Add("enableSshAccess", $true)


New-AzureRmResourceGroup -Name $resourceGroupName -Location $location
New-AzureRmResourceGroupDeployment -Name $resourceGroupName -ResourceGroupName $resourceGroupName -TemplateParameterObject $param -TemplateUri $templateUri

