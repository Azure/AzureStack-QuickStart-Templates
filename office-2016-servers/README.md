# Office 2016 Workloads

Office workloads (Exchange 2016, SharePoint 2016 and Skype for Business 2015) designed & validated to run on Azure Stack for up to 250 users.
Additional required Workloads: Active Directory, Certificate Authority, FileServer using S2D, SQL Server 2017 

The preview templates are designed,validated and supported to work with Azure Stack beeing conneted or disconnected. Any changes to the templates will break supportability. 


## Requirements

### Azure Stack

THe following Marketplace Items must be installed on Azure Stack:

- Windows Server 2016 Full Image
- SQL Server 2017 Enterprise Windows Image
- DSC Extension
- Antimalware Extension
- SQL IAAS Extension
- Custom Script Extension for Windows


### Exchange 2016

Latest Exchange CU 8 or 9 ISO file stored in .\artifacts\exchange2016-ha folder

UcmaRuntimeSetup.exe file stored in .\artifacts\exchange2016-ha folder

(https://www.microsoft.com/en-us/download/details.aspx?id=34992)

Note: A Product Key for Exchange 2016 Enterprise has to be provided as parameter. CU 10 is not supported for initial deployment and must be applied manually post deployment




## Deployment

### Deploy Manually via Portal
1. Download artifacts and content
2. Download additional files like ISO as called out for the individual products
3. Create Storage Account, Blob Container with access set to blob
4. Upload the content from the artifacts folder
5. Deploy the Templates in the following order: AD, CA, S2D, Exchange 2016, SQL 2017

### Deploy automated via PowerShell
1. Download artifacts and content
2. Download additional files like ISO as called out for the individual products
3. Adjust the parameter in PrepareAndDeploy.ps1
4. Run the PrepareaAndDeploy.ps1 PowerShell script

### Connect

The Virtual Machines do not have public IPs assigned, as a result you can not RDP to the machines. Deploy an additional VM with a public IP as a "Jumpbox" for troubleshooting or create
a site to site VPN to access via the internal network. Publishing is done via Windows Application Proxy.

### Content

.\Templates
This folder contains all the individual product templates

.\Artifacts
This folder contains requires DSC and Setup files

.\PrepareOnly.ps1
This will create a storage account and uploads all artifacts. This is typically used when you plan to deploy the templates manually one by one using Portal, PS or CLI

.\PrepareAndDeploy.ps1
This will create a storage account, uploads all artifacts and starts an automated deployment end to end. In this scenario make sure you adjust the azuredeploy.parameters.json file in each template subdirectory.
