This directory contains Bicep samples for AzureStack

To convert any AzureStack ARM template to Bicep, add api version within each resource declaration. API profile is not yet supported in Bicep. Here is the [tracking feature request](https://github.com/Azure/bicep/issues/851). 

Main categories of error during conversion:
1. Error BCP079: This expression is referencing its own declaration, which is not allowed.
    * Workaround - [GitHub issue](https://github.com/Azure/bicep/issues/1860)
2. Error BCP034: The enclosing array expected an item of type "module[] | (resource | module) | resource[]", but the provided item was of type "string".
    * This is when bicep decompile is not able to recognize the dependent resource and tries to convert the “dependsOn” defined in ARM template. The workaround is to modify the generated bicep template to either create implicit dependency or add the resource (not the resource id as used in ARM template) in dependsOn parameter. [Doc link](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/compare-template-syntax#resource-dependencies)

Az CLI Bicep commands
```
# Convert ARM template to Bicep template
az bicep decompile --file .\azuredeploy.json 
# Generate ARM template from Bicep template 
az bicep build --file .\azuredeploy.bicep --outfile bicepgenerated.json
# Deploy ARM/Bicep template
az deployment group create --resource-group testrg --template-file <ARM/Bicep template> --parameters .\azuredeploy.parameters.json
```