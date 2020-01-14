# Docker Registry v2 on Azure Stack

This template deploys an Ubuntu Server 16.04-LTS virtual machine along with a [custom script extension](script.sh) that installs and configures a [container registry](https://docs.docker.com/registry/) as a docker swarm service.

The deployed registry will be configured to persist container images in an Azure Stack storage account, encrypt traffic using TLS, and restrict access using basic HTTP authentication.

## Pre-requisites

Make sure you take care of the following pre-requisites before you start the setup process:

- `Ubuntu Server 16.04-LTS` was syndicated from Azure Stack's Marketplace by the operator
- `Custom Script Extensions for Linux 2.0` was syndicated from Azure Stack's Marketplace by the operator
- You have access to a X.509 certificate in PFX format
- You can [connect](https://docs.microsoft.com/en-us/azure-stack/user/azure-stack-powershell-configure-user) to the target Azure Stack instance using PowerShell

## Setup

The following section details the required steps to perform before you deploy the template. It also includes a few PowerShell snippets meant to speed up the setup process.

Once you went through the details, you should be able to tweak the [setup script](setup.ps1) and adjust it to your needs.

### Storage configuration

The template instructs the container registry to use the [Azure storage driver](https://docs.docker.com/registry/storage-drivers/azure/) to persist the container images in a local storage account blob container.

### Key Vault configuration

The deployment template will instruct Azure Resource Manager to drop your certificate in the virtual machine's file system. User credentials should be stored as secrets in the same local Key Vault instance where the PFX certificate is stored.

### Basic Authorization

User credentials should be stored as secrets in the same local Key Vault instance where the PFX certificate is stored. This can be achieved using the web UI or the SDK.

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

In order to upgrade the guest OS or the container registry itself, update [azuredeploy.json](azuredeploy.json) as needed and run once again `New-AzureRmResourceGroupDeployment` as previously indicated.

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
