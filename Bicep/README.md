---
page_type: sample
languages: 
- bicep
products: 
- templates
description: "Sample Bicep templates to deploy resources on AzureStackHub"
urlFragment: AzureStack-QuickStart-Templates
---

# This directory contains Bicep samples for AzureStackHub

## Project Bicep - an ARM DSL
Please visit the [Project Bicep](https://github.com/Azure/bicep/blob/main/README.md) main page for full information and links.

## What is Bicep?

Bicep is a Domain Specific Language (DSL) for deploying Azure resources declaratively. It aims to drastically simplify the authoring experience with a cleaner syntax, improved type safety, and better support for modularity and code re-use. Bicep is a **transparent abstraction** over ARM and ARM templates, which means anything that can be done in an ARM Template can be done in Bicep (outside of temporary [known limitations](#known-limitations)). All resource `types`, `apiVersions`, and `properties` that are valid in an ARM template are equally valid in Bicep on day one (Note: even if Bicep warns that type information is not available for a resource, it can still be deployed).


Bicep code is transpiled to standard ARM Template JSON files, which effectively treats the ARM Template as an Intermediate Language (IL).

[![Video overview of Bicep](http://img.youtube.com/vi/l85qv_1N2_A/0.jpg)](http://www.youtube.com/watch?v=l85qv_1N2_A "Azure Bicep March 2021: Learn everything about the next generation of ARM Templates")


## Bicep and Azure Stack Hub

Azure Stack Hub uses ARM (check [this article](https://docs.microsoft.com/azure-stack/user/azure-stack-develop-templates) for more information and considerations) and enables an easy conversion of the [AzStackHub QuickStart Templates](https://aka.ms/azurestackgithub).

To convert any AzureStack ARM template to Bicep, you'll need to add the api version within each resource declaration. API profile is not yet supported in Bicep. Here is the [tracking feature request](https://github.com/Azure/bicep/issues/851). 

### Getting started

1.	Ensure the “https://github.com/Azure/bicep/blob/main/README.md#get-started-with-bicep” are completed
2. Set the Azure Stack Hub environment – make sure the correct API Profile is used for Azure Stack Hub:

```
az cloud register `
    -n <environmentname> `
    --endpoint-resource-manager https://management.<region>.<fqdn> `
    --suffix-storage-endpoint "<fqdn>" `
    --suffix-keyvault-dns ".vault.<fqdn>" `
    --profile 2020-09-01-hybrid

az cloud set -n <environmentname>
az login --tenant contoso.onmicrosoft.com 

```

Az CLI Bicep commands
```
# Convert ARM template to Bicep template
az bicep decompile --file .\azuredeploy.json 
# Generate ARM template from Bicep template 
az bicep build --file .\azuredeploy.bicep --outfile bicepgenerated.json
# Deploy ARM/Bicep template
az deployment group create --resource-group testrg --template-file <ARM/Bicep template> --parameters .\azuredeploy.parameters.json
```

### Known issues

Main categories of error during conversion:
1. Error BCP079: This expression is referencing its own declaration, which is not allowed.
    * Workaround - [GitHub issue](https://github.com/Azure/bicep/issues/1860)
2. Error BCP034: The enclosing array expected an item of type "module[] | (resource | module) | resource[]", but the provided item was of type "string".
    * This is when bicep decompile is not able to recognize the dependent resource and tries to convert the “dependsOn” defined in ARM template. The workaround is to modify the generated bicep template to either create implicit dependency or add the resource (not the resource id as used in ARM template) in dependsOn parameter. [Doc link](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/compare-template-syntax#resource-dependencies)
