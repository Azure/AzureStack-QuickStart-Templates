$resources = New-Object System.Collections.ArrayList

 $resources.AddRange((
 [Tuple]::Create("Microsoft.Compute","virtualMachineScaleSets"),
 [Tuple]::Create("Microsoft.Storage","storageAccounts"),
 [Tuple]::Create("Microsoft.OperationalInsights","workspaces"),
 [Tuple]::Create("Microsoft.OperationalInsights","workspaces/dataSources"),
 [Tuple]::Create("Microsoft.Network","loadBalancers"),
 [Tuple]::Create("Microsoft.Network","publicIPAddresses"),
 [Tuple]::Create("Microsoft.Network","virtualNetworks"),
 [Tuple]::Create("Microsoft.Resources","deployments"),
 [Tuple]::Create("Microsoft.Network","networkSecurityGroups"),
 [Tuple]::Create("Microsoft.KeyVault","vaults"),
 [Tuple]::Create("Microsoft.Network","connections")
 ));
 
 
foreach ($resource in $resources){
    Write-Output "$($resource.Item1)/$($resource.Item2): $(((Get-AzureRmResourceProvider -ProviderNamespace $resource.Item1).ResourceTypes | Where-Object ResourceTypeName -eq $resource.Item2).ApiVersions[0])"
}