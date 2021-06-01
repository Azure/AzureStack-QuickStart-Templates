# Office 2016 Workloads

Office workloads (Exchange 2016, SharePoint 2016 and Skype for Business 2015) designed & validated to run on Azure Stack for up to 250 users.
Additional required workloads: Active Directory, Certificate Authority, FileServer using S2D, SQL Server 2017, AD FS, Windows Application Proxy (WAP)

The preview templates are designed, validated and supported to work with Azure Stack beeing connected or disconnected. Any changes to the templates will break supportability. 


## Requirements

### Azure Stack

THe following Marketplace Items must be installed on Azure Stack:

- Windows Server 2016 Full Image
- SQL Server 2017 Enterprise Windows Image
- DSC Extension
- Antimalware Extension
- SQL IAAS Extension
- Custom Script Extension for Windows
- Azure Diagnostic Extension for Windows
- Azure Performance Diagnostic


### Exchange 2016

Does install a 4 Node DAG with 9 Databases. Each Node has 10 data drives attached, each 460 GB in size.

#### Requirements not provided with the download
Latest Exchange CU 8 or 9 ISO file stored in .\artifacts\exchange2016-ha folder

UcmaRuntimeSetup.exe file stored in .\artifacts\exchange2016-ha folder

(https://www.microsoft.com/en-us/download/details.aspx?id=34992)

Note: A Product Key for Exchange 2016 Enterprise has to be provided as parameter. 

### Skype for Business 2015

Does install 3 Skype for Business - 2 Front End Servers and 2 Edge Servers

#### Requirements not provided with the download
Skype for Business 2015 ISO file stored in .\artifacts\sfb2015 folder

### SharePoint 2016
Does install SharePoint 2016 with 2 Front End and 2 Application Servers

#### Requirements not provided with the download

SharePoint 2016 ISO file stored in .\artifacts\sp2016-ha folder

sts2016-kb4032256-fullfile-x64-glb.exe file stored in .\artifacts\sp2016-ha folder
(https://www.microsoft.com/en-us/download/details.aspx?id=57222)

wssloc2016-kb4022231-fullfile-x64-glb.exe file stored in .\artifacts\sp2016-ha folder
(https://www.microsoft.com/en-us/download/details.aspx?id=57236)

Note: A Product Key has to be provided as parameter. 


## Deployment

### Deploy manually via Portal
1. Download artifacts and templates
2. Download additional files like ISO as called out for the individual products
3. Create Storage Account, Blob Container with access set to blob
4. Upload the content from the artifacts folder
5. Deploy the Templates in the following order: AD, WAP, CA, S2D, Exchange 2016, SQL 2017, SharePoint 2016, Skype for Business 2015, ADFS

### Deploy automated via PowerShell
1. Download artifacts and content
2. Download additional files like ISO as called out for the individual products
3. Adjust each .\Template\Example\azuredeploy.parameters.json file with your values 
3. Run the PrepareAndDeploy.ps1 PowerShell script

### Connect

The Virtual Machines do not have public IPs assigned, as a result you can not RDP to the machines. Deploy an additional VM with a public IP as a "Jumpbox" for troubleshooting or create
a site to site VPN to access via the internal network. Publishing is done via Windows Application Proxy.

### Content

.\Templates
This folder contains all the individual product templates

.\Artifacts
This folder contains required DSC, Custom scripts and Setup files

.\PrepareOnly.ps1
This will create a storage account and uploads all artifacts. This is typically used when you plan to deploy the templates manually one by one using Portal, PS or CLI

.\PrepareAndDeploy.ps1
This will create a storage account, uploads all artifacts and starts an automated deployment end to end. In this scenario make sure you adjust the azuredeploy.parameters.json file in each template subdirectory.
