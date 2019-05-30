# Docker Registry on Azure Stack

This template deploys a unsecure (no TLS encryption) docker registry that uses an existing Azure Stack storage account to persist your container images.

This template is just for illustrative purposes only and it is **not** recommended for production environments.

## Prerequisites

1. Ubuntu Server 16.04 is syndicated from Azure Stack's Marketplace
2. Custom Script Extensions for Linux 2.0  is syndicated from Azure Stack's Marketplace
3. A storage account where persist container images

## Usage

### HTTP Registries

You have to explicitly allow your docker client access to unsecure registries before you can use interact with it.

That can be done by adding a new entry to `insecure-registries` in your `daemon.json` configuration file. More information [here](https://docs.docker.com/registry/insecure/#deploy-a-plain-http-registry).

### Populate your Registry

Your registry can store images you produce yourself or images from any public registry. The only requirement is to apply the appropriate [tag](https://docs.docker.com/engine/reference/commandline/tag/#tag-an-image-for-a-private-repository) to the images.

```bash
# fetch an image from docker hub
docker pull hello-world:latest
# re-tag it using your registry information
# my-registry => Public IP DNS Label
docker tag hello-world:latest my-registry:80/hello-world:latest
# push to your private registry
docker push my-registry:80/hello-world:latest
```

## Future improvements

- Run multiple containers
- Support/document self signed certs
- Support/document CA issued cert