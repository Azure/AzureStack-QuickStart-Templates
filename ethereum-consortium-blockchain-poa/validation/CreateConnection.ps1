Param(
    [string] $resourceGroupNameLeader,
    [string] $resourceGroupNameMember,
    [string] $sharedKey,
    [string] $connectionName
   )
   
   function GeneratePrefix()
   {
       $seed = [guid]::NewGuid()
       return "e"+$seed.ToString().Substring(0,5)
   }
   
   function DownloadFile(
                       [String] $Uri,
                       [String] $Destination
                       )
   {
       $webclient = New-Object System.Net.WebClient
       $webclient.DownloadFile($Uri,$Destination)
   }
   
   $deploymentOutputLeader = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupNameLeader)[-1].Outputs
   $deploymentOutputMember = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupNameMember)[-1].Outputs
   
   $gatewayIdLeader = $deploymentOutputLeader["consortium_member_gateway_id_region1"].Value
   $gatewayIdMember = $deploymentOutputMember["consortium_member_gateway_id_region1"].Value
   $consortiumData = $deploymentOutputLeader["consortium_data_URL"].Value

   Write-Output("Downloading file from " + $consortiumData + "/ConsortiumBridge.psm1")
   # run the connection script
   DownloadFile -Uri ($consortiumData+"/ConsortiumBridge.psm1") -Destination ".\ConsortiumBridge.psm1"
   Import-Module ".\ConsortiumBridge.psm1"
   Write-Output("Connecting " + $gatewayIdLeader + " to " + $gatewayIdMember)
   CreateConnection $gatewayIdLeader $gatewayIdMember $connectionName $sharedKey 