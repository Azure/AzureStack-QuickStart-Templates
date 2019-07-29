function Random-Name {
  Param ([int]$length)
  -join ((97..122) | Get-Random -Count $length | % {[char]$_})
}

$location = ""
$resourceGroup = ""
$saName = Random-Name 10
$saContainer = Random-Name 10
$tokenIni = Get-Date
$tokenEnd = $tokenIni.AddYears(1.0)

$kvName = Random-Name 10
$secretName = Random-Name 10
$pfxPath = ""
$pfxPass = ""


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
$saKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroup -AccountName $saName)[0].Value

# Create container
Write-Host "Creating blob container:" $saContainer
Set-AzureRmCurrentStorageAccount -ResourceGroupName $resourceGroup -AccountName $saName | out-null
$container = New-AzureStorageContainer -Name $saContainer

# Upload configuration script
Write-Host "Uploading configuration script"
Set-AzureStorageBlobContent -Container $saContainer -File script.sh | out-null
$cseToken = New-AzureStorageBlobSASToken -Container $saContainer -Blob "script.sh" -Permission r -StartTime $tokenIni -ExpiryTime $tokenEnd
$cseUrl = $container.CloudBlobContainer.Uri.AbsoluteUri + "/script.sh" + $cseToken

# Upload htpasswd
Write-Host "Uploading htpasswd file"
Set-AzureStorageBlobContent -Container $saContainer -File .htpasswd | out-null
$htpasswdToken = New-AzureStorageBlobSASToken -Container $saContainer -Blob .htpasswd -Permission r -StartTime $tokenIni -ExpiryTime $tokenEnd
$htpasswdUrl = $container.CloudBlobContainer.Uri.AbsoluteUri + "/.htpasswd" + $htpasswdToken


# KEY VAULT
# =============================================

# Create key vault enabled for deployment
Write-Host "Creating key vault:" $kvName
$kv = New-AzureRmKeyVault -ResourceGroupName $resourceGroup -VaultName $kvName -Location $location -Sku standard -EnabledForDeployment

# Serialize certificate
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

# Upload certificate as secret
Write-Host "Storing certificate in key vault:" $pfxPath
$kvSecret = Set-AzureKeyVaultSecret -VaultName $kvName -Name $secretName -SecretValue $secret

# Compute certificate thumbprint
Write-Host "Computing certificate thumbprint"
$tp = Get-PfxCertificate -FilePath $pfxPath


# BUILD TEMPLATE PARAMETERS JSON
# =============================================
$jsonParameters = New-Object -TypeName PSObject

$jsonStorageAccountName = New-Object -TypeName PSObject
$jsonStorageAccountName | Add-Member -MemberType NoteProperty -Name value -Value $saName
$jsonParameters | Add-Member -MemberType NoteProperty -Name storageAccountName -Value $jsonStorageAccountName

$jsonStorageAccountContainerName = New-Object -TypeName PSObject
$jsonStorageAccountContainerName | Add-Member -MemberType NoteProperty -Name value -Value $saContainer
$jsonParameters | Add-Member -MemberType NoteProperty -Name storageAccountContainer -Value $jsonStorageAccountContainerName

$jsonStorageAccountKey = New-Object -TypeName PSObject
$jsonStorageAccountKey | Add-Member -MemberType NoteProperty -Name value -Value $saKey
$jsonParameters | Add-Member -MemberType NoteProperty -Name storageAccountKey -Value $jsonStorageAccountKey

$jsonKeyVaultResourceId = New-Object -TypeName PSObject
$jsonKeyVaultResourceId | Add-Member -MemberType NoteProperty -Name value -Value $kv.ResourceId
$jsonParameters | Add-Member -MemberType NoteProperty -Name keyVaultResourceId -Value $jsonKeyVaultResourceId

$jsonKeyVaultSecretUrl = New-Object -TypeName PSObject
$jsonKeyVaultSecretUrl | Add-Member -MemberType NoteProperty -Name value -Value $kvSecret.Id
$jsonParameters | Add-Member -MemberType NoteProperty -Name keyVaultSecretUrl -Value $jsonKeyVaultSecretUrl

$jsonCertificateThumbprint = New-Object -TypeName PSObject
$jsonCertificateThumbprint | Add-Member -MemberType NoteProperty -Name value -Value $tp.Thumbprint
$jsonParameters | Add-Member -MemberType NoteProperty -Name certificateThumbprint -Value $jsonCertificateThumbprint

$jsonAdminPublicKey = New-Object -TypeName PSObject
$jsonAdminPublicKey | Add-Member -MemberType NoteProperty -Name value -Value ""
$jsonParameters | Add-Member -MemberType NoteProperty -Name adminPublicKey -Value $jsonAdminPublicKey

$jsonDomainNameLabel = New-Object -TypeName PSObject
$jsonDomainNameLabel | Add-Member -MemberType NoteProperty -Name value -Value ""
$jsonParameters | Add-Member -MemberType NoteProperty -Name domainNameLabel -Value $jsonDomainNameLabel

$jsonCseLocation = New-Object -TypeName PSObject
$jsonCseLocation | Add-Member -MemberType NoteProperty -Name value -Value $cseUrl
$jsonParameters | Add-Member -MemberType NoteProperty -Name cseLocation -Value $jsonCseLocation

$jsonHtpasswdLocation = New-Object -TypeName PSObject
$jsonHtpasswdLocation | Add-Member -MemberType NoteProperty -Name value -Value $htpasswdUrl
$jsonParameters | Add-Member -MemberType NoteProperty -Name htpasswdLocation -Value $jsonHtpasswdLocation

$jsonRoot = New-Object -TypeName PSObject
$jsonRoot | Add-Member -MemberType NoteProperty -Name schema -Value "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#"
$jsonRoot | Add-Member -MemberType NoteProperty -Name contentVersion -Value "1.0.0.0"
$jsonRoot | Add-Member -MemberType NoteProperty -Name parameters -Value $jsonParameters

$jsonRoot | ConvertTo-Json | Set-Content -Path azuredeploy.parameters.json
