# Set variables to match your environment
$name = ""
$endpoint = ""
$tenant = ""
$subscription = ""

# Connect to Azure / Azure Stack
Add-AzureRMEnvironment -Name $name -ArmEndpoint $endpoint

$authEndpoint = (Get-AzureRmEnvironment -Name $name).ActiveDirectoryAuthority.TrimEnd('/')
$tenantId = (invoke-restmethod "$($authEndpoint)/$($tenant)/.well-known/openid-configuration").issuer.TrimEnd('/').Split('/')[-1]

Add-AzureRmAccount -EnvironmentName $name -TenantId $tenantId
Select-AzureRmSubscription -Subscription $subscription | out-null
