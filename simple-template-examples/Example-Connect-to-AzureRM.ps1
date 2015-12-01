###########
# CONNECT #
###########

# Add specific Azure Stack Environment
$AadTenantId = "3dc25382-d7d1-4e5a-ad19-2fb47f1571c2" #GUID Specific to the AAD Tenant
 
Add-AzureRmEnvironment -Name 'Azure Stack' `
    -ActiveDirectoryEndpoint ("https://login.windows.net/$AadTenantId/") `
    -ActiveDirectoryServiceEndpointResourceId "https://azurestack.local-api/" `
    -ResourceManagerEndpoint ("https://api.azurestack.local/") `
    -GalleryEndpoint ("https://gallery.azurestack.local:30016/") `
    -GraphEndpoint "https://graph.windows.net/"
 
# Get Azure Stack Environment Information
$env = Get-AzureRmEnvironment 'Azure Stack'

# Authenticate to AAD with Azure Stack Environment
Add-AzureRmAccount -Environment $env -Verbose

# Get Azure Stack Environment Subscription
$SubName = "Best Sub"
Get-AzureRmSubscription -SubscriptionName $SubName | Select-AzureRmSubscription