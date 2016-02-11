# Microsoft Azure Stack Quickstart Templates

This repository contains Azure Resource Manager deployment templates that have been tested on the first Technical Preview of Microsoft Azure Stack. 

## What repository?

The primary ARM templates repository on GitHub is the azure-quickstart-templates. You can find the repository here https://github.com/Azure/azure-quickstart-templates
Over time many GitHub users have contributed to the repository, resulting in a huge collection of more than 250 deployment templates. This repository is a great starting point to get a better understanding of how you can deploy various kinds of environment to Microsoft Azure. If you scroll through the templates in the azure-quickstart-templates repository, you will notice that there are templates that reference services (resource providers) that are not part of the Microsoft Azure Stack Technical Preview, such as ExpressRoute or CDN. 

To ensure the successful deployment of templates to both Microsoft Azure and Microsoft Azure Stack Technical Preview, this temporary GitHub repository AzureStack-quickstart-templates was created. This repository contains a few samples to test your Microsoft Azure Stack Technical Preview environment. Over time, some templates from this temporary repository will be moved to the azure-quickstart-templates repository and this temporary AzureStack-quickstart-templates repository will disappear.

**If you want to contribute your ARM templates to GitHub, you should make your contribution to the azure-quickstart-templates repository.**

## Contribution Guide

The azure-quickstart-templates repository contains an extensive contribution guide. When you perform a pull-request to the repository, Microsoft will evaluate the code in your pull request based on the guidelines in the contribution guide. You should definitely read the contribution guide. You can find the contribution guide by browsing to the azure-quickstart-templates repository in GitHub and the open the first folder in the repository called [1-CONTRIBUTION-GUIDE](https://github.com/Azure/azure-quickstart-templates/tree/master/1-CONTRIBUTION-GUIDE).


The contribution guide also explains how to ensure that your deployment template complies with the requirements for it to show up on the gallery in the public Microsoft Azure website.

## Azure Resource Manager limitations in Microsoft Azure Stack Technical Preview

You can use all kind of template functions within your deployment template. You can find a description of these template functions here: https://azure.microsoft.com/en-us/documentation/articles/resource-group-template-functions/

To ensure that the templates that you create will deploy to both Microsoft Azure and Microsoft Azure Stack Technical Preview, you must be aware of  a couple of limitations related to Azure Resource Manager in the first Technical Preview of Microsoft Azure Stack. Some functions of Azure Resource Manager are not yet available in this Technical Preview release of Microsoft Azure Stack. 

The following template functions are not available in Microsoft Azure Stack Technical Preview yet.

 * subString
 * Trim
 * uniqueString
 * Uri
 * concat (only works for string values, not for arrays)

The following validation functions for parameters are not available in Microsoft Azure Stack Technical Preview yet.

 * minLength
 * maxLength
 * minValue
 * maxValue

Also take note that the maximum number of outputs in a template is limited to ten. If you define more output values in your template the deployment will fail with the following error.

`Error submitting the deployment request. Additional details from the underlying API that might be helpful: Deployment template validation failed: 'The number of template output parameters limit exceeded. Expected 10 and actual 12.'.`

### API Versions for Resource Providers

Each resource provider in Microsoft Azure has its own API version. The first Technical Preview of Microsoft Azure Stack will support the current API versions for the available resource providers, with some minor exceptions. To ensure your template will succesfully deploy to both Microsoft Azure and the first technical preview of Microsoft Azure Stack, use the latest API versions that are available in the first technical Preview of Azure Stack for all resources in your template. To retrieve a list of the available API versions connect to your Microsoft Azure Stack Technical Preview environment by following the **Authenticate PowerShell with Microsoft Azure Stack** procedure described in this article.

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

Please note that this cmdlet does not verify the resource provider specific properties for the resources within the template. This cmdlet can be used for Microsoft Azure and Microsoft Azure Stack Technical Preview.

## Guidelines for Microsoft Azure Stack deployment templates

There are a couple of additional guidelines you should be aware of if you are contributing your deployment templates to the azure-quickstart-templates repository.

 * Your README.md file should contain a table that describes to what endpoint the deployment is tested.
 * Your template should be deployable to Microsoft Azure with the "deploy to Microsoft Azure" button that must be in your README.md file
 * The location of your resources should be set or the location of the resource group
 * The storageAccountName should be a fixed value and prepended with a unique string
 * The endpoint of your storage namespace should be parameterized, with a defaultValue of "core.windows.net"

### README.md

The README.md describes your deployment. A good description helps other community members to understand your deployment. The README.md uses Github Flavored Markdown for formatting text. To quickly identify a template that is tested for deployment to Microsoft Azure and to Microsoft Azure Stack, the following table should be added to the top of your README.md file. Update the table after you have validated the Deployment script to each endpoint.

| Endpoint | Version | Validated |
| ------------- |:-------------:| -----:|
| Microsoft Azure | - | no |
| Microsoft Azure Stack | TP1 | no |

Do not include the parameters or the variables of the deployment script. We render this on Azure.com from the template. Specifying these in the README.md will result in duplicate entries on Azure.com.

You can download a [sample README.md](../master/Sample README.md) here to use for your own contributions. This folder also contains some example README.md files.

### Deploy to Azure button

The README.md file of your deployment folder should contain a good description of what will be deployed with your deployment template. Besides the description the README.md file should also contains a "Deploy to Azure" button. You can create a button by adding the following code to your README.md

```HTML
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/<replace with the encoded raw path of your azuredeploy.json>" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/></a>
```

For example, if you want create a "Deploy to Azure" Button for the deployment template in  https://github.com/Azure/azure-quickstart-templates/tree/master/101-vnet-two-subnets, open the azuredeploy.json file in the repository.


Click the "Raw" button on the menu. This opens the raw code of the template without any surrounding HTML code. Copy the URL in the header of the browser. In this example: `https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/101-vnet-two-subnets/azuredeploy.json`

Next we need to encode the URL. Open your favorite search engine and search for URL encoder. Paste the URL in an online encoder, encode the URL and copy the result. In this example the encoded result is `https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2F101-vnet-two-subnets%2Fazuredeploy.json`

Update the README.md file by replacing the <replace with the encoded raw path of your azuredeploy.json> code with the result from the URL encoder. In this example the following code creates the working "Download to Azure" button.

```HTML
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2F101-vnet-two-subnets%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/></a>
```

### Location

Do not use a parameter to specify the location. Use the location property of the resourceGroup instead. By using the `resourceGroup().location` expression for all your resources, the resources in the template will automatically be deployed in the same location as the resource group.

```JSON
"resources": [
{
  "name": "[variables('storageAccountName')]",
  "type": "Microsoft.Storage/storageAccounts",
  "apiVersion": "[variables('apiVersionStorage')]",
  "location": "[resourceGroup().location]",
  "comments": "This storage account is used to store the VM disks",
  "properties": {
    "accountType": "Standard_GRS"
  }
}
]
```

### Storage accountname

Storage account names need to be lower case and can't contain hyphens (-) in addition to other domain name restrictions. A storage account has a limit of 24 characters. They also need to be globally unique on Microsoft Azure. The template function uniqueString is the preferred option used to prevent deployment issues on Microsoft Azure. The function uniqueString is not available in this Technical Preview, and deployments of templates containing this function on the Technical Preview of Microsoft Azure Stack will fail. The guidance for this technical preview is to create one parameter and two variables to randomize the storagAccountName

```JSON
  "parameters": {
    "storageAccountName": {
      "type": "string",
      "metadata": {
        "description": "provide a name for your storage acount of max 11 characters"
      }
    }
  },
  "variables": {
    "storageAccountNumber": "[length(parameters('storageAccountName'))]",
    "storageAccountName":"[replace(replace(tolower(concat(parameters('storageAccountName'), variables('storageAccountNumber'))), '-',''),'.','')]"
  }
```

Once uniqueString is added to ARM in a future technical preview release of Microsoft Azure Stack this sample will be updated based on uniqueString.  


### Storage endpoint namespace

If you use Storage in your template, Create a parameter to specify the storage namespace. Set the default value of the parameter to core.windows.net. Additional endpoints can be specified in the allowed value property. 

```JSON
"parameters": {
"storageNamespace": {
  "type": "string",
  "defaultValue": "core.windows.net",
  "allowedValues": [
    "core.windows.net",
    "azurestack.local"
  ],
  "metadata": {
    "description": "The endpoint namespace for storage"
  }
}
}
```

Create a variable that concatenates the storageAccountname and the namespace to a URI.

```JSON
"variables": {
"diskUri":"[concat('http://',variables('storageAccountName'),'.blob.'parameters('storageEndpoint'),'/',variables('vmStorageAccountContainerName'),'/',variables('OSDiskName'),'.vhd')]"
}
```

## Next steps

Start with creating a couple of deployment templates in your own repository. Make sure they deploy to both Microsoft Azure and Microsoft Azure Stack Technical Preview, they are in line with the guidelines in the azure-quickstart-templates contribution guide and the guidelines described here. Fork the azure-quickstart-templates repository, add or update and send pull requests to the azure-quickstart-templates. If your templates comply with the requirments they will even show up in the gallery on the public Microsoft Azure website.
