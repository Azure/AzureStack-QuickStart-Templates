function Get-ThumbprintFromPfx($PfxFilePath, $Password) 
    {
        return New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($PfxFilePath, $Password)
    }

function Publish-SecretToKeyVault ($PfxFilePath, $Password, $KeyVaultName)
   {
        $keyVaultSecretName = "ClusterCertificate"
        $certContentInBytes = [io.file]::ReadAllBytes($PfxFilePath)
        $pfxAsBase64EncodedString = [System.Convert]::ToBase64String($certContentInBytes)

        $jsonObject = ConvertTo-Json -Depth 10 ([pscustomobject]@{
            data     = $pfxAsBase64EncodedString
            dataType = 'pfx'
            password = $Password
        })

        $jsonObjectBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonObject)
        $jsonEncoded = [System.Convert]::ToBase64String($jsonObjectBytes)
        $secret = ConvertTo-SecureString -String $jsonEncoded -AsPlainText -Force
        $keyVaultSecret = Set-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $keyVaultSecretName -SecretValue $secret
        
        $pfxCertObject = Get-ThumbprintFromPfx -PfxFilePath $PfxFilePath -Password $Password

        Write-Host "KeyVault id: " -ForegroundColor Green
        (Get-AzureRmKeyVault -VaultName $KeyVaultName).ResourceId
        
        Write-Host "Secret Id: " -ForegroundColor Green
        (Get-AzureKeyVaultSecret -VaultName $KeyVaultName -Name $keyVaultSecretName).id

        Write-Host "Cluster Certificate Thumbprint: " -ForegroundColor Green
        $pfxCertObject.Thumbprint
   }

#========================== CHANGE THESE VALUES ===============================
$armEndpoint = "https://management.local.azurestack.external"
$tenantId = "246aaa85-9030-40d8-a0f0-d94b15dc002c"
$location = "redmond"

$clusterCertPfxPath = "C:\Users\shnatara\Documents\SFCerts\ClusterCert.pfx"
$clusterCertPfxPassword = "PASSWOrD@1"
#==============================================================================

Add-AzureRmEnvironment -Name AzureStack -ARMEndpoint $armEndpoint
Login-AzureRmAccount -Environment AzureStack -TenantId $tenantId
Select-AzureRmSubscription -Subscription c2823111-9538-482c-ac42-6d18bc87b806

$rgName = "sfvaultrg"
Write-Host "Creating Resource Group..." -ForegroundColor Yellow
New-AzureRmResourceGroup -Name $rgName -Location $location

Write-Host "Creating Key Vault..." -ForegroundColor Yellow
$Vault = New-AzureRmKeyVault -VaultName sfvault -ResourceGroupName $rgName -Location $location -EnabledForTemplateDeployment -EnabledForDeployment -EnabledForDiskEncryption

Write-Host "Publishing certificate to Vault..." -ForegroundColor Yellow
Publish-SecretToKeyVault -PfxFilePath $clusterCertPfxPath -Password $clusterCertPfxPassword -KeyVaultName $vault.VaultName