# EXCHANGE 2016 CU1 INSTALLATION

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAzureStack-QuickStart-Templates%2Fdevelop%2Fexchange-2016-non-ha%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAzureStack-QuickStart-Templates%2Fdevelop%2Fexchange-2016-non-ha%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

This template deploys Exchange 2016.

`Tags: [exchange, mailbox]`

| Endpoint        | Version           | Validated  |
| ------------- |:-------------:| -----:|
| Microsoft Azure      | - | YES |
| Microsoft Azure Stack      | - |  YES |

## Deployed resources

The following resources are deployed as part of the solution
####[Exchange 2016 Non-HA]
[Deploys a VM, install pre-requisites, downloads Exchange 2016 ISO, install Exchange 2016 on a seperate disk drive (E:) and create Mailbox on a seperate disk drive (F:)]
+ **Public IP Address**: Allows connection to a VM
+ **Network Security Group**: 
+ **Storage Account**: VHDs, Result blobs storage
+ **Network Interface**: 
+ **Virtual Network**: 
+ **Virtual Machine**: To run Jetstress test
+ **DSC Extension**: Install Exchange 2016

## EXCHANGE (2016) INSTALLATION FOR AZURESTACK ##


<b>DESCRIPTION</b>

This template deploys requested number of VMs with public IP address in same virtual network. DSC installs Exchange 2016 Cumulative Update 1.

Please make sure to user unique resource group name for each deployment to avoid deployment failures due to name collisions of resources.

NOTE: There is a 90 minutes Azure time-out which you can hit if internet connection is slower to download installation files and takes longer than 60 minutes.

NOTE: To use Exchange Management Shell in compatibility mode, use PowerShell code snippet given below-

```PowerShell
Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010
& 'E:\Exchange\Bin\RemoteExchange.ps1'
```


<b>PARAMETERS</b>
```PowerShell
exchangeVMCount: 2 #[Number of VMs to deploy and run jestress workload]

exchangeStorageSize: 10GB #[Exchange Mailbox size in bytes]
```
