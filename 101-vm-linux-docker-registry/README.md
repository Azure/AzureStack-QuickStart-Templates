# Docker Registry v2 on Azure Stack

This template deploys an Ubuntu Server 16.04-LTS virtual machine along with a [custom script extension](script.sh) that installs and configures a [container registry](https://docs.docker.com/registry/) as a docker swarm service.

The deployed registry will be configured to persist container images in an Azure Stack storage account, encrypt traffic using TLS, and restrict access using basic HTTP authentication.

## Pre-requisites

Make sure you take care of the following pre-requisites before you start the setup process:

- `Ubuntu Server 16.04-LTS` was syndicated from Azure Stack's Marketplace by the operator
- `Custom Script Extensions for Linux 2.0` was syndicated from Azure Stack's Marketplace by the operator
- You have access to a X.509 certificate in PFX format
- You can execute [htpasswd](https://httpd.apache.org/docs/2.4/programs/htpasswd.html) to generate the authorized users credentials
- You can [connect](https://docs.microsoft.com/en-us/azure-stack/user/azure-stack-powershell-configure-user) to the target Azure Stack instance using PowerShell

## Setup

The following section details the required steps to perform before you deploy the template. It also includes a few PowerShell snippets meant to speed up the setup process.

Once you went through the details, you should be able to tweak the [setup script](setup.ps1) and adjust it to your needs.

### Basic Authentication using .htpasswd files

`htpasswd` is a small command-line utility that creates and updates text files (usually named `.htpasswd`) used to store user credentials for basic HTTP authentication.

An usage example is shown below (add flag `-c` to create file `.htpasswd`):

```bash
htpasswd -Bb .htpasswd my-user my-password
```

#### Anonymous access

To allow anonymous access to the registry, update the `docker run` command executed by the [CSE script](script.sh) **before** you start the [storage configuration](#storage-configuration) step.

Deleting the lines that set variables REGISTRY_AUTH, REGISTRY_AUTH_HTPASSWD_PATH AND REGISTRY_AUTH_HTPASSWD_REALM will disable basic authentication.

### Storage configuration

The template instructs the container registry to use the [Azure storage driver](https://docs.docker.com/registry/storage-drivers/azure/) to persist the container images in a local storage account blob container.

We will also store the `.htpasswd` file in the same storage account to keep it secure and readily available when you need to upgrade your registry or guest OS to a new version.

You can use the PowerShell snipped below to automate the storage account setup process:

```powershell
# Set variables to match your environment
$location = "your-location"
$resourceGroup = "registry-rg"
$saName = "registry"
$saContainer = "images"
$tokenIni = Get-Date
$tokenEnd = $tokenIni.AddYears(1.0)

# Create resource group
Write-Host "Creating resource group:" $resourceGroup
New-AzureRmResourceGroup -Name $resourceGroup -Location $location | out-null

# Create storage account
Write-Host "Creating storage account:" $saName
$sa = New-AzureRmStorageAccount -ResourceGroupName $resourceGroup -AccountName $saName -Location $location -SkuName Premium_LRS -EnableHttpsTrafficOnly 1
$saKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroup -AccountName $saName)[0].Value

# Create blob container
Write-Host "Creating blob container:" $saContainer
Set-AzureRmCurrentStorageAccount -ResourceGroupName $resourceGroup -AccountName $saName | out-null
$container = New-AzureStorageContainer -Name $saContainer

# Upload the CSE script so the template can later fetch it during deployment
Write-Host "Uploading configuration script"
Set-AzureStorageBlobContent -Container $saContainer -File script.sh | out-null
$cseToken = New-AzureStorageBlobSASToken -Container $saContainer -Blob "script.sh" -Permission r -StartTime $tokenIni -ExpiryTime $tokenEnd
$cseUrl = $container.CloudBlobContainer.Uri.AbsoluteUri + "/script.sh" + $cseToken

# The CSE script needs the .htpasswd file to configure the container registry
Write-Host "Uploading .htpasswd file"
Set-AzureStorageBlobContent -Container $saContainer -File .htpasswd | out-null
# Get htpasswd download URL
$htpasswdToken = New-AzureStorageBlobSASToken -Container $saContainer -Blob .htpasswd -Permission r -StartTime $tokenIni -ExpiryTime $tokenEnd
$htpasswdUrl = $container.CloudBlobContainer.Uri.AbsoluteUri + "/.htpasswd" + $htpasswdToken
```

## Key Vault configuration

The deployment template will instruct Azure Resource Manager to drop your certificate in the virtual machine's file system.

The snippet below creates the Key Vault resource and uploads the .pfx certificate.

```powershell
$kvName = "certs"
$secretName = "registry"
$pfxPath = "cert.pfx"
$pfxPass = ""

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
```

### Certificate thumbprint

Your certificate thumbprint is a required parameter of the ARM template. The CSE script uses that information to find the certificate in the virtual machine' file system.

Run the following snipped to generate the certificate thumbprint:

```powershell
Write-Host "Computing certificate thumbprint"
$tp = Get-PfxCertificate -FilePath $pfxPath
```

## Template deployment

### First time deployment

Once setup is completed and the required parameters populated in [azuredeploy.parameters.json](azuredeploy.parameters.json), you can deploy the template with the following command:

```powershell
$resourceGroup=""

New-AzureRmResourceGroupDeployment `
  -Name "RegistryDeployment-$((Get-Date).ToString("yyyyMMddHHmmss"))" `
  -ResourceGroupName $resourceGroup `
  -TemplateFile "azuredeploy.json" `
  -TemplateParameterFile "azuredeploy.parameters.json"
```

### Upgrade

In order to upgrade the guest OS or the container registry itself, update [azuredeploy.json](azuredeploy.json) and/or [script.sh](script.sh) as needed and run once again `New-AzureRmResourceGroupDeployment` as previously indicated.

## Usage

### Populate your Registry

Your registry can store images you produce yourself or images from any public registry. The only requirement is to apply the appropriate [tag](https://docs.docker.com/engine/reference/commandline/tag/#tag-an-image-for-a-private-repository) to the container images before you push to it.

```powershell
# login if needed
docker login -u my-user -p my-password  my-registry.com
# fetch an image from docker hub
docker pull hello-world:latest
# re-tag it using your registry information
# my-registry => Public IP DNS Label
docker tag hello-world:latest my-registry.com/hello-world:latest
# push to your private registry
docker push my-registry.com/hello-world:latest
```

## FAQ

### Can I use a self-signed certificate?

Yes. You can use this PowerShell snipped to generate a self-signed certificate. 

```powershell
$PASSWORD=""
$CN=""

# Create a self-signed certificate
$ssc = New-SelfSignedCertificate -certstorelocation cert:\LocalMachine\My -dnsname $CN
$crt = "cert:\localMachine\my\" + $ssc.Thumbprint
$pwd = ConvertTo-SecureString -String $PASSWORD -Force -AsPlainText
Export-PfxCertificate -cert $crt -FilePath "cert.pfx" -Password $pwd
```

or using `openssl`

```bash
PASSWORD=""
CN=""

openssl req -x509 -newkey rsa:2048 -subj "/CN=${CN}" -days 365 -out cert.crt -keyout cert.pem -passout pass:${PASSWORD}
```

Restart the docker daemon once the self-signed certificate is trusted by the registry client.

### I do not have a .pfx certificate, I got a private key and a public key pair (.crt and .key)

You can use `openssl` to create a .pfx out of a public and private key.

```bash
openssl pkcs12 -export -in cert.crt -inkey cert.pem  -passin pass:${PASSWORD} -out cert.pfx -passout pass:${PASSWORD}
```

### The ARM deployment went through fine, but the registry does not seem to be working. How can I troubleshoot it?

The template blocks SSH traffic (TCP 22) by default. You need to add a new inbound rule to allow SSH traffic through the Network Security Group.

Once you are able to remote into the virtual machine, you can inspect the provisioning logs at `/var/log/azure/docker-registry.log`

If that's not enough, looking at the container logs should give you an idea of what the problem may be.

```bash
docker logs registry ${CONTAINER_ID}
```
