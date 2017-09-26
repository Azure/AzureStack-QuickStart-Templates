# [IaaS Linux VM]

<a href="http://armviz.io/#/?load=https://raw.githubusercontent.com/Azure/azurestack-quickstart-templates/master/101-simple-linux-vm/azuredeploy.json" target="_blank">
  <img src="http://armviz.io/visualizebutton.png"/>
</a>
This template deploys a simple Linux VM such as ubuntu 14.04, ubuntu 15.10, sles 12 SP1, CentOS 6.7, CentOS 7.2

`Tags: [Linux]`

| Endpoint        | Version           | Validated  |
| ------------- |:-------------:| -----:|
| Microsoft Azure Stack      | - |  yes|

## Prerequisites

Follow the below links to create/download a Linux Image and upload the same to Azure Stack's Platform Image Repository
1. https://azure.microsoft.com/en-us/documentation/articles/azure-stack-linux/ 
2. https://azure.microsoft.com/en-us/documentation/articles/azure-stack-add-image-pir/
	Note: please use the default values for linuxPublisher, linuxOffer, linuxSku, linuxVersion found in azuredeploy.json or parameters.json while creating the manifest.json in PIR

## Deployment steps
1. Deploy to Azure Stack portal using custom deployment
2. Deploy through Visual Studio using azuredeploy.json and azuredeploy.parameters.json. Note: for other Linux versions deployment, rename the *.azuredeploy.parameters.json to the default name before deploying via VisualStudio
2. Deploy the solution from PowerShell with the following PowerShell script 

``` PowerShell
## Configure the environment with the Add-AzureRmEnvironment cmdlt 
Follow the below link to configure the Azure Stack environment with Add-AzureRmEnvironment cmdlet and authenticate a user to the environment
https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-powershell-configure


# Set Deployment Variables
$myNum = "001" #Modify this per deployment
$RGName = "myRG$myNum"
$myLocation = "local"

$templateFile= "azuredeploy.json"
$templateParameterFile= "azuredeploy.parameters.json"
# For Suse $templateParameterFile= "suse.12.sp1.azuredeploy.parameters.json"
# For CentOS 6.7 $templateParameterFile= "centos.6.7.azuredeploy.parameters.json"
# For CentOS 7.2 $templateParameterFile= "centos.7.2.azuredeploy.parameters.json"

# Create Resource Group for Template Deployment
New-AzureRmResourceGroup -Name $RGName -Location $myLocation

# Deploy Template 
New-AzureRmResourceGroupDeployment `
    -ResourceGroupName $RGName `
    -TemplateFile $templateFile `
    -TemplateParameterFile $templateParameterFile
```


