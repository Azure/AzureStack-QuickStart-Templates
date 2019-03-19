# Azure BackupS erver

This Template deploys Azure Backup Server. 
You can find more information about Azure Backup Server here: https://docs.microsoft.com/en-us/azure/backup/backup-mabs-install-azure-stack


## Requirements

### Azure Stack

THe following Marketplace Items must be installed on Azure Stack:

- Windows Server 2016 Full Image
- DSC Extension
- Antimalware Extension
- Custom Script Extension for Windows
- Azure Diagnostic Extension for Windows
- Azure Performance Diagnostic


### Azure Backup Server

- Azure Subscription
- Vault Credential File
- Azure Backup Server V3 setup files

## Deployment

### Deploy manually via Portal
1. Download artifacts and template
2. Create Vault in Azure
3. Download Vault Credentials File and Azure Backup Server Version 3
4. Store the downloaded content in the artifacts folder
4. Upload the content from the artifacts folder into a new storage account
5. Deploy the Template

### Content

.\Artifacts
This folder contains required DSC, Custom scripts and Setup files
