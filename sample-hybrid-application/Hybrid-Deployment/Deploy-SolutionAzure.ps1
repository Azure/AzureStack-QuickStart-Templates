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
      [Parameter(Mandatory=$true)][System.String]$ADAppPassword,
      [Parameter(Mandatory=$true)][System.String]$emailNotification,
      [Parameter()][System.String]$Path)

Function GetJson {
    [CmdletBinding()]
    Param([Parameter(Mandatory=$true)][System.String]$Path)
    $file = Get-Item -Path $Path
    Get-Content -Path $file.FullName | ConvertFrom-Json | Write-Output
}

#region Removes AzureStack ArmProfile 
Install-Module -Name AzureRM -RequiredVersion 5.7.0 -Force
Import-Module -Name AzureRM -RequiredVersion 5.7.0 -Force
#endregion

#region Use Credentials for Azure public cloud
Login-AzureRmAccount
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
$myLocation = $availLocations[$selectedRegionIndex]
$location  = $myLocation.Location
Write-Output $location 
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

#region Sets file location Variables for Json files
$azureStackTemplateLocation = (Get-Item .\Hybrid-AzureStack\azuredeploy.json).FullName
$azureStackParamLocation = (Get-Item .\Hybrid-AzureStack\azurestackdeploy.parameters.json).FullName
$azureTemplateLocation = (Get-Item .\Hybrid-Azure\azuredeploy.json).FullName
$azureParamLocation = (Get-Item .\Hybrid-Azure\azuredeploy.parameters.json).FullName
#endregion

#region Deploys template to Azure
$deploySettings = @{
    Name = 'Azure-S2S-Deploy'
    ResourceGroupName= $rg 
    TemplateFile = $azureTemplateLocation
    TemplateParameterFile = $azureParamLocation
    Verbose = $true
}
New-AzureRmResourceGroupDeployment @deploySettings
#endregion

#region Gets values from Json Files 
$json = GetJson -Path $azureParamLocation
$json2 = GetJson -Path $azureTemplateLocation
$json3 = GetJson -Path $azureStackParamLocation
#endregion

#region Gives Values for Local Network Gateway
$gatewayIP = Get-AzureRmPublicIpAddress -Name $json2.variables.GatewayNamePublicIP -ResourceGroupName $rg
$localIP = Get-AzureRmVirtualNetwork -ResourceGroupName $rg
Write-Host
Write-Host "In the Azure Stack Portal for your Local Network GatewayIP Address enter this IP: $($gatewayIP.IpAddress) " -ForegroundColor Green
Write-Host "Please Enter the Correct IP's for your Local Network Gateway from Portal once done press any key to continue" -ForegroundColor Yellow
Read-Host
#endregion

#region Sets Variables for Webapp URI Connection String
$webApp = Get-AzureRmWebApp -Name $json.parameters.siteName.value -ResourceGroupName $rg
#endregion

#region Adds Database Connection string to WebApp Appsettings in Azure Portal
$config = Import-Csv -Path vmInfo.csv
$SQLServerName = $config.sqlServerName
$sa = $config.userName
$saPWD = $config.userPWD
$SQLIP = $config.SQLIP
$hostName = $config.hostName
$webapp.SiteConfig.ConnectionStrings.Add((New-Object Microsoft.Azure.Management.WebSites.Models.ConnStringInfo -ArgumentList SQLServer, ${SQLServerName}, “Data Source=${SQLIP},1433;Initial Catalog=NorthwindDb;User ID=$sa;Password=$saPWD;Asynchronous Processing=True”))
$webApp | Set-AzureRmWebApp
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
$split = $webApp.HostNames
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

#region Updates Appsettings file with new connection string value
$appsetingsFile = (Get-Item .\appsettings.json).FullName
$ConnectObject = GetJson -path $appsetingsFile
$appkey = Get-AzureRmApplicationInsights -ResourceGroupName $rg
$ConnectObject.ConnectionStrings.DefaultConnection = $webApp.SiteConfig.ConnectionStrings.ConnectionString
$ConnectObject.ApplicationInsights.InstrumentationKey = $appkey.InstrumentationKey
$ConnectObject | ConvertTo-Json | Out-File .\appsettings.json
#endregion

#region Uploads new appsettings.json file
$apiUrl = "$NewAppUri/api/vfs/site/wwwroot/appsettings.json"
$filePath = ".\appsettings.json"
Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -UserAgent $userAgent -Method PUT -InFile $filePath -ContentType "multipart/form-data"
#endregion

#region Post deployment - Connect VPN Azure to Azure Stack:
$gw = Get-AzureRmVirtualNetworkGateway -Name Gateway -ResourceGroupName $rg
$ls = Get-AzureRmLocalNetworkGateway -Name LocalGateway -ResourceGroupName $rg
New-AzureRMVirtualNetworkGatewayConnection -Name Azure-AzureStack -ResourceGroupName $rg -Location $location -VirtualNetworkGateway1 $gw -LocalNetworkGateway2 $ls -ConnectionType IPsec -RoutingWeight 10 -SharedKey $presharedkey
#endregion

#region Gets Deployment so we can use paramter values from Json File
$lastDeployment = Get-AzureRmResourceGroupDeployment -ResourceGroupName $rg -Name Azure-S2S-Deploy
#endregion

#region Configure traffic Manager Endpoints
$azureProfile = Get-AzureRmTrafficManagerProfile -Name TrafficManager -ResourceGroupName $rg
$webapp = Get-AzureRMWebApp -Name $lastDeployment.Parameters["siteName"].Value
Add-AzureRmTrafficManagerEndpointConfig -EndpointName Azure-Endpoint -TrafficManagerProfile $azureProfile -Type AzureEndpoints -TargetResourceId $webapp[0].Id -EndpointStatus Disabled -Weight 1
$azureProfile.Endpoints[0].Target = $webapp[0].DefaultHostName
$azureProfile.Endpoints[0].Priority = 3
Add-AzureRmTrafficManagerEndpointConfig -EndpointName AzureStack-Endpoint -TrafficManagerProfile $azureProfile -Type ExternalEndpoints -Target $hostName -EndpointLocation $location -EndpointStatus Enabled -Weight 2
Set-AzureRmTrafficManagerProfile -TrafficManagerProfile $azureProfile
#endregion

#region Outputs URL of Traffic Manager Endpoint to update in Azure Stack Web App
$traffic = "$($azureProfile.RelativeDnsName)" + ".trafficmanager.net"
Write-Host "Please add URL below to ""HOSTNAMES ASSIGNED TO SITE"" on your Azure Stack WebAbb Settings" -ForegroundColor Yellow
Write-Host $traffic -ForegroundColor Green
Read-Host -Prompt "Once Updated....Press Any Key when done"
#endregion

#region Configures Scale Out and In
$subscriptionID = $subscription.Id
$webAppName = $webapp[0].Name
$rule1 = New-AzureRmAutoscaleRule -MetricName "CpuPercentage" `
                                          -MetricResourceId "/subscriptions/$subscriptionID/resourceGroups/$rg/providers/Microsoft.Web/serverFarms/$webAppName" `
                                          -MetricStatistic Average `
                                          -Operator GreaterThan `
                                          -Threshold 50 `
                                          -TimeGrain 00:05:00  `
                                          -ScaleActionDirection Increase `
                                          -ScaleActionCooldown 00:10:00 `
                                          -ScaleActionValue 2

$rule2 = New-AzureRmAutoscaleRule -MetricName "CpuPercentage" `
                                          -MetricResourceId "/subscriptions/$subscriptionID/resourceGroups/$rg/providers/Microsoft.Web/serverFarms/$webAppName" `
                                          -MetricStatistic Average `
                                          -Operator Lessthan `
                                          -Threshold 30 `
                                          -TimeGrain 00:05:00  `
                                          -ScaleActionDirection Decrease `
                                          -ScaleActionCooldown 00:10:00 `
                                          -ScaleActionValue 1
 
$AutoScaleProfile = New-AzureRmAutoscaleProfile -DefaultCapacity "1" -MaximumCapacity "10" -MinimumCapacity "1" -Rules $rule1,$rule2 -Name "Scale up and Down"
   
Add-AzureRmAutoscaleSetting -Location $location `
                            -Name "ScaleOut" `
                            -ResourceGroup $rg `
                            -TargetResourceId "/subscriptions/$subscriptionID/resourceGroups/$rg/providers/microsoft.web/serverFarms/$webAppName" `
                            -AutoscaleProfiles $AutoScaleProfile
#endregion

#region Creates Service Principle for Function Trigger
$securePass = ConvertTo-SecureString $ADAppPassword -AsPlainText -Force 
$azureadapp = New-AzureRmADApplication -DisplayName "TriggerApp" -HomePage "http://localhost" -IdentifierUris "http://localhost" 
$servp = New-AzureRmADServicePrincipal -ApplicationId $azureadapp.ApplicationId 
$appCredential = New-AzureRmADAppCredential -ApplicationId $azureadapp.ApplicationId -Password $securePass
Sleep 20
New-AzureRmRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $azureadapp.ApplicationId 
#endregion

#region Prompts User to configure App Key in Azure Portal
Write-Host "Please Go To Azure Portal and Create a Key and Copy Secret Given"
$azureAppSecret =  Read-Host -Prompt "Please Enter App Secret Created from Azure Portal"
#endregion

#region Modifies csx file
$csx = get-content .\cross-cloud-scale\httpTrigger\run.csx
$csx[30] = $csx[30].Replace("SERVICE_PRINCIPAL_ID", $azureadapp.ApplicationId.Guid).Replace("SERVICE_PRINCIPAL_KEY", $azureAppSecret).Replace("DIRECTORY_ID", $subscription.TenantId)
$csx[33] = $csx[33].Replace("AZURE_RESOURCE_GROUP", $rg).Replace("TRAFFIC_MANAGER_NAME", "TrafficManager")
$csx[34] = $csx[34].Replace("AZURE_RESOURCE_GROUP", $rg).Replace("AZURE_WEB_APP_NAME", $webAppName)
$csx[42] = $csx[42].Replace("AZURE_TRAFFIC_MANAGER_ENDPOINT_NAME", "Azure-Endpoint")
$csx[58] = $csx[58].Replace("AZURE_TRAFFIC_MANAGER_ENDPOINT_NAME", "Azure-Endpoint")
Set-Content -Path .\cross-cloud-scale\httpTrigger\run.csx -Value $csx
#endregion

#region Checks if App name exists if not Creates the function App
$functionAppName = "$webAppName" + "Function"
$functionAppResource = Get-AzureRmResource | Where-Object {$_.ResourceName -eq $functionAppName -And $_.ResourceType -eq 'Microsoft.Web/Sites'}
 if ($functionAppResource -eq $null){
   New-AzureRmResource -ResourceType 'Microsoft.Web/Sites' -ResourceName $functionAppName -Kind 'functionapp' -Location $location -ResourceGroupName $rg -Properties @{} -Force

$functionAppSettings = @{
                            FUNCTIONS_EXTENSION_VERSION = '~2'
                        }
$setWebAppParams = @{
                        Name = $functionAppName
                        ResourceGroupName = $rg
                        AppSettings = $functionAppSettings
                        }
$webApp = Set-AzureRmWebApp @setWebAppParams

}
#endregion

#region Creates Credential and connects to Azure Function WebApp
$creds = Invoke-AzureRmResourceAction -ResourceGroupName $rg -ResourceType Microsoft.Web/sites/config -ResourceName "$($functionAppName)/publishingcredentials" -Action list -ApiVersion 2015-08-01 -Force
$username = $creds.Properties.PublishingUserName
$password = $creds.Properties.PublishingPassword
# Note that the $username here should look like `SomeUserName`, and **not** `SomeSite\SomeUserName`
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $password)))
$userAgent = "powershell/1.0"
#endregion

#region Uploads Zip to Function WebApp
Compress-Archive -Path .\cross-cloud-scale\* -DestinationPath .\host 
$filePath = (Get-Item .\host.zip).FullName
$apiUrl = "https://$functionAppName.scm.azurewebsites.net/api/zipdeploy"
$Results = Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -UserAgent $userAgent -Method POST -InFile $filePath -ContentType "multipart/form-data" -Verbose
#endregion

#region Restarts Function App to force Re-Build
sleep 60
Restart-AzureRmWebApp -ResourceGroupName $rg -Name $functionAppName
sleep 30
#endregion

#region Configures App Insights and Email Alert
$actionEmail = New-AzureRmAlertRuleEmail -CustomEmail $emailNotification -SendToServiceOwners
$actionWebhook1 = New-AzureRmAlertRuleWebhook -ServiceUri "https://$functionAppName.azurewebsites.net/api/httpTrigger&action=azs"
$actionWebhook2 = New-AzureRmAlertRuleWebhook -ServiceUri "https://$functionAppName.azurewebsites.net/api/httpTrigger&action=azure"

Add-AzureRmMetricAlertRule -Name "Burst into Azure Cloud 1" `
                           -Location $location `
                           -ResourceGroup $rg `
                           -Operator GreaterThan `
                           -Threshold 2 `
                           -TargetResourceId "/subscriptions/$subscriptionID/resourceGroups/$rg/providers/Microsoft.Insights/components/$webAppName-AppInsights" `
                           -WindowSize 00:05:00 `
                           -TimeAggregationOperator Total `
                           -MetricName "request.rate" `
                           -Actions $actionEmail,$actionWebhook1 `
                           -Description "Emails when Scaled Out"

Add-AzureRmMetricAlertRule -Name "Scale Back into Azure Stack 1" `
                           -Location $location `
                           -ResourceGroup $rg `
                           -Operator LessThan `
                           -Threshold 2 `
                           -TargetResourceId "/subscriptions/$subscriptionID/resourceGroups/$rg/providers/Microsoft.Insights/components/$webAppName-AppInsights" `
                           -WindowSize 00:05:00 `
                           -TimeAggregationOperator Total `
                           -MetricName "request.rate" `
                           -Actions $actionEmail, $actionWebhook2 `
                           -Description "Emails when Scaled back in"
#endregion



#iyhnX1hUSCpTAJKj3U5Lry+wGFxaCcErADaRUxAAW/4=