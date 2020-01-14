# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license.

$location = ""
$resourceGroup = ""
$saName = ""
$saContainer = ""

$kvName = ""
$pfxSecret = ""
$pfxPath = ""
$pfxPass = ""
$spnName = ""
$spnSecret = ""
$userName = ""
$userPass = ""

$dnsLabelName = ""
$sshKey = ""
$vmSize = ""
$registryTag = "2.7.1"
$registryReplicas = "5"

# RESOURCE GROUP
# =============================================

# Create resource group
Write-Host "Creating resource group:" $resourceGroup
New-AzureRmResourceGroup -Name $resourceGroup -Location $location | out-null


# STORAGE ACCOUNT
# =============================================

# Create storage account
Write-Host "Creating storage account:" $saName
$sa = New-AzureRmStorageAccount -ResourceGroupName $resourceGroup -AccountName $saName -Location $location -SkuName Premium_LRS -EnableHttpsTrafficOnly 1

# Create container
Write-Host "Creating blob container:" $saContainer
Set-AzureRmCurrentStorageAccount -ResourceGroupName $resourceGroup -AccountName $saName | out-null
New-AzureStorageContainer -Name $saContainer | out-null

Write-Host "=> Storage Account Resource ID:" $sa.Id

Write-Host "Assigning contributor role to" $spnName
New-AzureRMRoleAssignment -ApplicationId $spnName -RoleDefinitionName "Contributor" -Scope $sa.Id

# KEY VAULT
# =============================================

# Create key vault enabled for deployment
Write-Host "Creating key vault:" $kvName
$kv = New-AzureRmKeyVault -ResourceGroupName $resourceGroup -VaultName $kvName -Location $location -Sku standard -EnabledForDeployment
Write-Host "=> Key Vault Resource ID:" $kv.ResourceId

Write-Host "Setting access polices for client" $spnName
Set-AzureRmKeyVaultAccessPolicy -VaultName $kvName -ServicePrincipalName $spnName -PermissionsToSecrets GET,LIST

# Store certificate as secret
Write-Host "Storing certificate in key vault:" $pfxPath
$fileContentBytes = get-content $pfxPath -Encoding Byte
$fileContentEncoded = [System.Convert]::ToBase64String($fileContentBytes)
$jsonObject = @"
{
"data": "$filecontentencoded",
"dataType" :"pfx",
"password": "$pfxPass"
}
"@
$jsonObjectBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonObject)
$jsonEncoded = [System.Convert]::ToBase64String($jsonObjectBytes)
$secret = ConvertTo-SecureString -String $jsonEncoded -AsPlainText -Force
$kvSecret = Set-AzureKeyVaultSecret -VaultName $kvName -Name $pfxSecret -SecretValue $secret -ContentType pfx

# Compute certificate thumbprint
Write-Host "Computing certificate thumbprint"
$tp = Get-PfxCertificate -FilePath $pfxPath

Write-Host "=> Certificate URL:" $kvSecret.Id
Write-Host "=> Certificate thumbprint:" $tp.Thumbprint

Write-Host "Storing secret for sample user: $userName"
$userSecret = ConvertTo-SecureString -String $userPass -AsPlainText -Force
Set-AzureKeyVaultSecret -VaultName $kvName -Name $userName -SecretValue $userSecret -ContentType "user credentials" | out-null


# BUILD TEMPLATE PARAMETERS JSON
# =============================================
$jsonParameters = New-Object -TypeName PSObject

$jsonAdminPublicKey = New-Object -TypeName PSObject
$jsonAdminPublicKey | Add-Member -MemberType NoteProperty -Name value -Value $sshKey
$jsonParameters | Add-Member -MemberType NoteProperty -Name adminPublicKey -Value $jsonAdminPublicKey

$jsonVirtualMachineSize = New-Object -TypeName PSObject
$jsonVirtualMachineSize | Add-Member -MemberType NoteProperty -Name value -Value $vmSize
$jsonParameters | Add-Member -MemberType NoteProperty -Name virtualMachineSize -Value $jsonVirtualMachineSize

$jsonPipName = New-Object -TypeName PSObject
$jsonPipName | Add-Member -MemberType NoteProperty -Name value -Value $dnsLabelName
$jsonParameters | Add-Member -MemberType NoteProperty -Name pipName -Value $jsonPipName

$jsonPipDomainNameLabel = New-Object -TypeName PSObject
$jsonPipDomainNameLabel | Add-Member -MemberType NoteProperty -Name value -Value $dnsLabelName
$jsonParameters | Add-Member -MemberType NoteProperty -Name pipDomainNameLabel -Value $jsonPipDomainNameLabel

$jsonStorageAccountResourceId = New-Object -TypeName PSObject
$jsonStorageAccountResourceId | Add-Member -MemberType NoteProperty -Name value -Value $sa.Id
$jsonParameters | Add-Member -MemberType NoteProperty -Name storageAccountResourceId -Value $jsonStorageAccountResourceId

$jsonStorageAccountContainerName = New-Object -TypeName PSObject
$jsonStorageAccountContainerName | Add-Member -MemberType NoteProperty -Name value -Value $saContainer
$jsonParameters | Add-Member -MemberType NoteProperty -Name storageAccountContainer -Value $jsonStorageAccountContainerName

$jsonKeyVaultResourceId = New-Object -TypeName PSObject
$jsonKeyVaultResourceId | Add-Member -MemberType NoteProperty -Name value -Value $kv.ResourceId
$jsonParameters | Add-Member -MemberType NoteProperty -Name pfxKeyVaultResourceId -Value $jsonKeyVaultResourceId

$jsonKeyVaultSecretUrl = New-Object -TypeName PSObject
$jsonKeyVaultSecretUrl | Add-Member -MemberType NoteProperty -Name value -Value $kvSecret.Id
$jsonParameters | Add-Member -MemberType NoteProperty -Name pfxKeyVaultSecretUrl -Value $jsonKeyVaultSecretUrl

$jsonCertificateThumbprint = New-Object -TypeName PSObject
$jsonCertificateThumbprint | Add-Member -MemberType NoteProperty -Name value -Value $tp.Thumbprint
$jsonParameters | Add-Member -MemberType NoteProperty -Name pfxThumbprint -Value $jsonCertificateThumbprint

$jsonRegistryTag = New-Object -TypeName PSObject
$jsonRegistryTag | Add-Member -MemberType NoteProperty -Name value -Value $registryTag 
$jsonParameters | Add-Member -MemberType NoteProperty -Name registryTag -Value $jsonRegistryTag

$jsonRegistryReplicas = New-Object -TypeName PSObject
$jsonRegistryReplicas | Add-Member -MemberType NoteProperty -Name value -Value $registryReplicas 
$jsonParameters | Add-Member -MemberType NoteProperty -Name registryReplicas -Value $jsonRegistryReplicas

$jsonSpnName = New-Object -TypeName PSObject
$jsonSpnName | Add-Member -MemberType NoteProperty -Name value -Value $spnName
$jsonParameters | Add-Member -MemberType NoteProperty -Name servicePrincipalClientId -Value $jsonSpnName

$jsonSpnSecret = New-Object -TypeName PSObject
$jsonSpnSecret | Add-Member -MemberType NoteProperty -Name value -Value $spnSecret
$jsonParameters | Add-Member -MemberType NoteProperty -Name servicePrincipalClientSecret -Value $jsonSpnSecret

$jsonRoot = New-Object -TypeName PSObject
$jsonRoot | Add-Member -MemberType NoteProperty -Name schema -Value "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#"
$jsonRoot | Add-Member -MemberType NoteProperty -Name contentVersion -Value "1.0.0.0"
$jsonRoot | Add-Member -MemberType NoteProperty -Name parameters -Value $jsonParameters

$jsonRoot | ConvertTo-Json | Set-Content -Path azuredeploy.parameters.json
