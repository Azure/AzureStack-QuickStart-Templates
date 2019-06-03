# Docker Registry on Azure Stack

This template deploys a docker registry that uses an existing Azure Stack storage account to persist your container images.

This template is just for illustrative purposes only and it is **not** recommended for production environments.

## Prerequisites

1. Ubuntu Server 16.04 is syndicated from Azure Stack's Marketplace
2. Custom Script Extensions for Linux 2.0 is syndicated from Azure Stack's Marketplace
3. A storage account to persist container images
4. A Key Vault instance [enabled for deployment](https://docs.microsoft.com/en-us/azure-stack/user/azure-stack-key-vault-push-secret-into-vm#create-a-key-vault-secret)
5. A X509 certificate and its private key stored as a Key Vault [secret](https://docs.microsoft.com/en-us/azure-stack/user/azure-stack-key-vault-manage-portal#create-a-secret)

## Setup

Like most web servers, your docker registry will need a X509 certificate to create a HTTPS channel. To automate the registry deployment process, this template assumes that your certificate and its corresponding private key are stored in a Key Vault instance as a PFX archive.

If your are planning to use `let's encrypt` as your CA, then the `certbot` client can generate the required files for you:

```bash
certbot certonly --standalone -d registry.example.com --email user@example.com
```

After that, you can create the `.pfx` archive with the following command

```bash
openssl pkcs12 -export -out cert.pfx -inkey privkey.pem -in cert.pem -certfile chain.pem
```

Remember to keep around the certificate fingerprint as the template requires it as an input parameter:

```bash
openssl x509 -in cert.crt -noout -fingerprint | cut -d= -f2 | sed 's/://g'
```

## Usage

### Populate your Registry

Your registry can store images you produce yourself or images from any public registry. The only requirement is to apply the appropriate [tag](https://docs.docker.com/engine/reference/commandline/tag/#tag-an-image-for-a-private-repository) to the images.

```bash
# fetch an image from docker hub
docker pull hello-world:latest
# re-tag it using your registry information
# my-registry => Public IP DNS Label
docker tag hello-world:latest my-registry/hello-world:latest
# push to your private registry
docker push my-registry/hello-world:latest
```

## Future improvements

- Run multiple containers
- Add KeyVault deployment
- Reduce number of mandatory parameters
- Support/document self signed certs
