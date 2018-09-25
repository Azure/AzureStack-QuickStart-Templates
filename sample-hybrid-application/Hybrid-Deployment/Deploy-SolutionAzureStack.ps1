<#
.DESCRIPTION
Reads in a list of files stored in JSON format.

.EXAMPLE
Sample.ps1 -Path .\test.json
Reads in test.json in the current directory.

.NOTES
Additional optional notes can go here. You could make a note of any prerequisites, conditions, etc.
For example. To make test.json you can use this command.
Get-ChildItem  | ConvertTo-Json | Out-File .\test.json
The order on which the items appear should not matter.
For more information you can use => Get-help about_comment_based_help

.PARAMETER Path
Path to the JSON file to read. Be sure to include a .PARAMETER entry for each Parameter.

.SYNOPSIS
Reads in a JSON list of files.
#>
[CmdletBinding()]
Param(
      [Parameter(Mandatory=$true)][System.String]$rg,
      [Parameter(Mandatory=$true)][System.String]$presharedkey,
      [Parameter(Mandatory=$true)][System.String]$storageAccountName,
      [Parameter(Mandatory=$true)][System.String]$targetStorageContainer,
      [Parameter(Mandatory=$true)][System.String]$AADTenantName,
      [Parameter(Mandatory=$true)][System.String]$azureStackArmEndpoint,
      [Parameter()][System.String]$Path)

Function GetJson {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)][System.String]$Path)
    $file = Get-Item -Path $Path
    Get-Content -Path $file.FullName | ConvertFrom-Json | Write-Output
}

#region Installs Profile for Azure Stack
Install-Module -Name AzureRm.BootStrapper -Force
Use-AzureRmProfile -Profile 2017-03-09-profile -Force
#endregion

#region Adds Environment and Logs into Tenant Subscription
$azureRMEnvironment = Add-AzureRMEnvironment -Name AzureStack -ArmEndpoint $azureStackArmEndpoint
$ADauth = (Get-AzureRmEnvironment -Name AzureStack).ActiveDirectoryAuthority
$endpt = "{0}{1}/.well-known/openid-configuration" -f $ADauth, $AADTenantName
$OauthMetadata = (Invoke-WebRequest -UseBasicParsing $endpt).Content | ConvertFrom-Json
$AADid = $OauthMetadata.Issuer.Split('/')[3]
$loginInfo = Login-AzureRmAccount -EnvironmentName "AzureStack" -TenantId $AADid
#endregion

#region Gets Subscription if only one subscription it selects if multiple subscriptions prompts you to chose
$subscriptions = Get-AzureRmSubscription
if ($subscriptions.GetType().Name -eq 'PSAzureSubscription') {
    $subscription = $subscriptions
}
else { 
    [int]$index = 1
    [bool]$isValidSubscription = $false

    Write-Host "Please select a subscription from below.  Enter the number in the list."
    foreach ($subscription in $subscriptions) {
        Write-Output "$index - $($subscription.Name)"
        $index++
    }

    while (-not $isValidSubscription) {
        $indexString = Read-Host -Prompt "Subscription number"

        try {
            [int]$selectedSubscriptionIndex = [int]::Parse($indexString) - 1
        }
        catch {
            Write-Host "Invalid selection, please enter a number between '1' and '$($subscriptions.Count)'"
            [int]$selectedSubscriptionIndex = 0
        }

        if (($selectedSubscriptionIndex -ge 1) -and ($selectedSubscriptionIndex -le $subscriptions.Count)) {
            $isValidSubscription = $true
        }
        else {
            Write-Host "Invalid selection, please enter a number between '1' and '$($subscriptions.Count)'"
        }
    }
}
if ($subscription -eq $null){
Write-Output "Selected subscription"
$selectedSubscription = $subscriptions[$selectedSubscriptionIndex]
Select-AzureRmSubscription -Subscription $selectedSubscription
Write-Output $selectedSubscription 
}

else{
Select-AzureRmSubscription -Subscription $subscription
Write-Output "Selected subscription"
Write-Output $subscription
}
#endregion

#region Gets Location if only one location it selects location if multiple locations prompts you to chose
$availLocations = Get-AzureRmLocation
if ($availLocations.GetType().Name -eq 'PSResourceProviderLocation') {
    $location = $availLocations.Location
}
else { 
    [int]$index = 1
    [bool]$isValidRegion = $false

    Write-Host "Please select a Region from below.  Enter the number in the list."
    foreach ($availLocation in $availLocations) {
        Write-Output "$index - $($availLocation.Location)"
        $index++
    }

    while (-not $isValidRegion) {
        $indexString = Read-Host -Prompt "Region"

        try {
            [int]$selectedRegionIndex = [int]::Parse($indexString) - 1
        }
        catch {
            Write-Host "Invalid selection, please enter a number between '1' and '$($availLocations.Count)'"
            [int]$selectedRegionIndex = 0
        }

        if (($selectedRegionIndex -ge 0) -and ($selectedRegionIndex -lt $availLocations.Count)) {
            $isValidRegion = $true
        }
        else {
            Write-Host "Invalid selection, please enter a number between '1' and '$($availLocations.Count)'"
        }
    }
}

Write-Output "Selected Region"
if ($location -eq $null){
$mylocation = $availLocations[$selectedRegionIndex]
$location  = $mylocation.Location
}

Write-Output $location 
#endregion

#region Sets file location Variables for Json files
$azureStackTemplateLocation = (Get-Item .\Hybrid-AzureStack\azuredeploy.json).FullName
$azureStackParamLocation = (Get-Item .\Hybrid-AzureStack\azurestackdeploy.parameters.json).FullName
$azureTemplateLocation = (Get-Item .\Hybrid-Azure\azuredeploy.json).FullName
$azureParamLocation = (Get-Item .\Hybrid-Azure\azuredeploy.parameters.json).FullName
#endregion

#region Creates Resource Group if exists it skips
$newAzureResourceGroup = Get-AzureRmResourceGroup | Where-Object ResourceGroupName -EQ $rg
if (!$newAzureResourceGroup) {
        
    #Write-Host "Creating resource group $RG in $location region" 
    New-AzureRmResourceGroup -Name $rg -Location $location | Out-Null
    $newAzureResourceGroup = $null
    while (!$newAzureResourceGroup) {
        $newAzureResourceGroup = Get-AzureRmResourceGroup -Name $rg
        Start-Sleep -Seconds 1
    }
}

else {
Write-Host "Resource Group $rg Already exists moving to next step......"  
}
#endregion

#region Creates Storage Account if one exists skips to next step
$azureStorageAcc = Get-AzureRmStorageAccount -Verbose | Where-Object StorageAccountName -EQ $storageAccountName.ToLower()
if ($azureStorageAcc) {
    Read-Host "Storage Account $storageAccountName Already exists moving to next step......Press Any Key to Continue" 
}
else
{
    while(!((Get-AzureRmStorageAccountNameAvailability -Name $storageAccountName).NameAvailable)) {
        Write-Warning -Message "'${storageAccountName}' is not available, please choose another name"
        $storageAccountName.ToLower() = Read-Host -Prompt "Enter a Storage Account Name"
    }
    Write-Host "Creating Storage Account '$storageAccountName'" 
    New-AzureRmStorageAccount -ResourceGroupName $rg -Name $storageAccountName -Location $location -Type Standard_LRS | Out-Null
    while (!$azureStorageAcc) {
        $azureStorageAcc = Get-AzureRmStorageAccount | Where-Object StorageAccountName -EQ $storageAccountName
        Start-Sleep -Seconds 1
    }
} 
#endregion

#region Creates Storage Container if one exists skips to the next step
$targetStore = Get-AzureRmStorageAccount -ResourceGroupName $rg -Name $storageAccountName
$newAzureStorageContainer = Get-AzureStorageContainer -Context $targetStore.Context | Where-Object Name -EQ $targetStorageContainer.ToLower()
if (!$newAzureStorageContainer) {
    Write-Host "Creating Storage Container $targetStorageContainer"  
    New-AzureStorageContainer -Name $targetStorageContainer -Context $targetStore.Context -Permission Container | Out-Null

        $newAzureStorageContainer = $null

while (!$newAzureStorageContainer) {
    $newAzureStorageContainer = Get-AzureStorageContainer -Name $targetStorageContainer -Context $targetStore.Context
    Start-Sleep -Seconds 1
    }    
}

else {
Read-Host "Storage Container $targetStorageContainer Already exists moving to next step......Press Any Key to Continue"  
}
#endregion

#region Uploads files to storage container
$Folder = ".\northwind"
Foreach ($File in (dir $Folder -File))
{ 
Set-AzureStorageBlobContent -Container $newAzureStorageContainer.Name -File $file.FullName -Blob $file.Name -Context $newAzureStorageContainer.Context
}
#endregion

#region Imports json files
$json = GetJson -Path $azureTemplateLocation
$json2 = GetJson -Path $azureParamLocation
$json3 = GetJson -Path $azureStackParamLocation
#endregion

#region updates base url parameter to new value of created container
$json3.parameters.baseUrl.value = $newAzureStorageContainer.CloudBlobContainer.Uri.AbsoluteUri 
$json3.parameters.serverFarmResourceGroup.value = $rg
$json3.parameters.subscriptionId.value = $subscription.Id
$json3 | ConvertTo-Json | Out-File .\Hybrid-AzureStack\azurestackdeploy.parameters.json
#endregion

#region refreshing files as we made changes
$json = GetJson -Path $azureTemplateLocation
$json2 = GetJson -Path $azureParamLocation
$json3 = GetJson -Path $azureStackParamLocation
#endregion

#region Deploys template to Azure
$Deploysettings = @{
    Name = 'AzureStack-S2S-Deploy'
    ResourceGroupName= $rg 
    TemplateFile = $azureStackTemplateLocation
    TemplateParameterFile = $azureStackParamLocation
    Verbose = $true
}
New-AzureRmResourceGroupDeployment @Deploysettings
#endregion

#region Gets Values for CSV file
$lastDeployment = Get-AzureRmResourceGroupDeployment -ResourceGroupName $rg -Name AzureStack-S2S-Deploy
$vm = Get-AzureRmVM -ResourceGroupName $rg -Name $lastDeployment[0].Outputs["vmName1"].Value
$nic = Get-AzureRmNetworkInterface -ResourceGroupName $rg -Name $(Split-Path -Leaf $vm.NetworkProfile.NetworkInterfaces[0].Id)
$sqlIPAdress = $nic.IpConfigurations | Select-Object PrivateIpAddress
$webApp = Get-AzureRMwebApp -Name $lastDeployment[0].Parameters["siteName"].Value -ResourceGroupName $rg
$publicIP = Get-AzureRmPublicIpAddress -ResourceGroupName $rg -Name myPublicIP | select-object IpAddress
$sqlPublicIP = $publicIP.IpAddress
#endregion

#region Writes variables to file
New-Object -TypeName PSCustomObject -Property @{
sqlServerName = $lastDeployment[0].Outputs["vmName1"].Value
userName = $lastDeployment[0].Outputs["adminUsername"].Value
userPWD = $lastDeployment[0].Outputs["adminPassword"].Value
SQLIP = $sqlIPAdress.PrivateIpAddress
hostName = $webApp[0].DefaultHostName
stackLocation = $location
} | Export-Csv -Path vmInfo.csv -NoTypeInformation
#endregion

#region Prompts user to update IP's in portal
Write-Host "Deployment complete" -ForegroundColor Green
Write-Host "Please Navigate to Azure (public) Portal and retrive the Gateway Ip Address" -ForegroundColor Yellow
Write-Host "Using that value update your AzureStack Local network gateway with the Gateway IP Address" -ForegroundColor Yellow
Write-Host "Once Updated.....Please Press Any Key to Create VPN Connection" -ForegroundColor Yellow
Read-Host
#endregion

#region Post deployment - Connect VPN AzureStack to Azure:
$gw = Get-AzureRmVirtualNetworkGateway -Name Az-Virt-Gateway -ResourceGroupName $rg
$ls = Get-AzureRmLocalNetworkGateway -Name Az-to-AzS-LocalGateway -ResourceGroupName $rg
New-AzureRMVirtualNetworkGatewayConnection -Name AzureStack-Azure -ResourceGroupName $rg -Location $location -VirtualNetworkGateway1 $gw -LocalNetworkGateway2 $ls -ConnectionType IPsec -RoutingWeight 10 -SharedKey $presharedkey
#endregion

#region Gets value for Public IP and Displays
$gatewayPip = Get-AzureRmPublicIpAddress -Name Gateway-PIP  -ResourceGroupName $rg
Write-Host "This is your LocalGatewayIPAddress (to be entered in Azure) :" $gatewayPip.IpAddress -ForegroundColor Green
Write-Host "Please Update your LocalGateway in Azure (Public) with the above IP Address" -ForegroundColor Green
#endregion

Write-Host "Don't Forget to Configure WebApp Networking in Azure Portal" -ForegroundColor Yellow
Write-Host "Once Updated.....Please Press Any Key to Configure On Premise Instance of WebApp" -ForegroundColor Yellow
Read-Host

#region Sets Variables for Webapp URI Connection String
$webApp = Get-AzureRMwebApp -Name $lastDeployment[0].Parameters["siteName"].Value -ResourceGroupName $rg
#endregion

#region Creates Credential and connects to Azure Web App
$creds = Invoke-AzureRmResourceAction -ResourceGroupName $rg -ResourceType Microsoft.Web/sites/config -ResourceName "$($webApp.Name)/publishingcredentials" -Action list -ApiVersion 2015-08-01 -Force
$username = $creds.Properties.PublishingUserName
$password = $creds.Properties.PublishingPassword
# Note that the $username here should look like `SomeUserName`, and **not** `SomeSite\SomeUserName`
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $password)))
$userAgent = "powershell/1.0"
#endregion

#region uses Webbapp URL and adds .scm to build string for use when creating the apiUrl  
$split = $webApp.DefaultHostName
[regex]$pattern = '\.'
$NewAppUri = "https://$($pattern.replace($split, '.scm.', 1))"
#endregion

#region Deletes old appsettings.json file
$Headers = @{
    'Authorization' = ('Basic {0}' -f $base64AuthInfo)
    'If-Match'      = '*'
}
$filePath = "$NewAppUri/api/vfs/site/wwwroot/appsettings.json"
Invoke-RestMethod -Uri $filePath -Headers $Headers -UserAgent $userAgent -Method Delete 
#endregion

#region Uploads new appsettings.json file
$apiUrl = "$NewAppUri/api/vfs/site/wwwroot/appsettings.json"
$filePath = ".\appsettings.json"
Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -UserAgent $userAgent -Method PUT -InFile $filePath -ContentType "multipart/form-data"
#endregion

#region Adds Database Connection string to WebApp Appsettings in Azure Portal
$config = Import-Csv -Path vmInfo.csv
$SQLServerName = $config.sqlServerName
$sa = $config.userName
$saPWD = $config.userPWD
$SQLIP = $config.SQLIP
$webapp.SiteConfig.ConnectionStrings.Add((New-Object Microsoft.Azure.Management.WebSites.Models.ConnStringInfo -ArgumentList SQLServer, DefaultConnection, “Data Source=${sqlPublicIP},1433;Initial Catalog=NorthwindDb;User ID=$sa;Password=$saPWD;Asynchronous Processing=True”))
$webApp | Set-AzureRmWebApp
#endregion