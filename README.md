# Microsoft Azure Stack Quickstart Templates

This repository contains Azure Resource Manager deployment templates that have been tested with Microsoft Azure Stack Development Kit. 

## What repository?

The primary Azure Resource Manager templates repository on GitHub is the azure-quickstart-templates. You can find the repository here https://github.com/Azure/azure-quickstart-templates

Over time many GitHub users have contributed to the repository, resulting in a huge collection of more than 400 deployment templates. This repository is a great starting point to get a better understanding of how you can deploy various kinds of environment to Microsoft Azure. If you scroll through the templates in the azure-quickstart-templates repository, you will notice that there are templates that reference services (resource providers) that are not part of Microsoft Azure Stack Development Kit, such as ExpressRoute or CDN. 

To ensure the successful deployment of templates to both Microsoft Azure and Microsoft Azure Stack Development Kit, this temporary GitHub repository AzureStack-quickstart-templates was created. This repository contains samples to test your Microsoft Azure Stack Development Kit environment. Over time, some templates from this temporary repository will be moved to the azure-quickstart-templates repository and this temporary AzureStack-quickstart-templates repository will be depreacated.

**If you want to contribute your Azure Resource Manager templates to GitHub, you should make your contribution to the azure-quickstart-templates repository.**

## Contribution Guide and best practices

The azure-quickstart-templates repository contains a contribution guide and best practices. When you perform a pull-request to the repository, Microsoft will evaluate the code in your pull request based on the guidelines in these documents. 

 * [Contribution-Guide](https://github.com/Azure/azure-quickstart-templates/blob/master/1-CONTRIBUTION-GUIDE/README.md#contribution-guide)
 * [Best-Practices](https://github.com/Azure/azure-quickstart-templates/blob/master/1-CONTRIBUTION-GUIDE/best-practices.md#best-practices)

Familiarizing yourself with these documentes, improves the contribution experience.

The contribution guide also explains how to ensure that your deployment template complies with the requirements for it to show up on the gallery in the public Microsoft Azure website.

## Azure Resource Manager limitations in Microsoft Azure Stack Development Kit

You can use all kind of template functions within your deployment template. You can find a description of these template functions here: https://azure.microsoft.com/en-us/documentation/articles/resource-group-template-functions/

To ensure that the templates that you create will deploy to both Microsoft Azure and Microsoft Azure Stack Development Kit, you must be aware of a couple of limitations related to Azure Resource Manager in the Microsoft Azure Stack Development Kit. Some functions of Azure Resource Manager are not yet available in this  release of Microsoft Azure Stack. 

The following template functions are not available in Microsoft Azure Stack Development Kit yet.

 * skip
 * take

### API Versions for Resource Providers

Each resource provider in Microsoft Azure has its own API version. Microsoft Azure Stack Development Kit supports the current API versions for the available resource providers, with some minor exceptions. To ensure your template will succesfully deploy to both Microsoft Azure and Microsoft Azure Stack Development Kit, use the latest API versions that are available in Microsoft Azure Stack Development Kit for all resources in your template. To retrieve a list of the available API versions connect to your Microsoft Azure Stack Development Kit environment by following the **Authenticate PowerShell with Microsoft Azure Stack** procedure described in this article.

https://azure.microsoft.com/en-us/documentation/articles/azure-stack-deploy-template-powershell/

When you are connected to your environment, you can retrieve a list of the available resource providers and the supported API versions by running the following PowerShell cmdlet

``` PowerShell
Get-AzureRmResourceProvider | Select ProviderNamespace -Expand ResourceTypes | FT Providernamespace, ResourceTypeName, ApiVersions
```

This cmdlet can also be used for Microsoft Azure.

### Validate existing deployment templates

You can verify if an existing deployment template is valid for a given environment with the Test-AzureRmResourceGroupDeployment PowerShell cmdlet. After connecting to your environment in a PowerShell session run the following PowerShell cmdlet

``` PowerShell
Test-AzureRmResourceGroupDeployment -ResourceGroupName ExampleGroup -TemplateFile c:\Templates\azuredeploy.json
```

Please note that this cmdlet does not verify the resource provider specific properties for the resources within the template. This cmdlet can be used for Microsoft Azure and Microsoft Azure Stack Development Kit.

## Next steps

Start with creating deployment templates in your own repository. Make sure they deploy to both Microsoft Azure and Microsoft Azure Stack Development Kit, they are in line with the guidelines in the azure-quickstart-templates contribution guide and the guidelines described here. Fork the azure-quickstart-templates repository, add or update and send pull requests to the azure-quickstart-templates. If your templates comply with the requirments they will even show up in the gallery on the public Microsoft Azure website.
