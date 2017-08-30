# JETSTRESS 2013 WORKLOAD FOR EXCHANGE 2016 CU1 ON AZURESTACK


<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAzureStack-QuickStart-Templates%2Fmaster%2Fjetstress-2013-exchange-loadtest%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAzureStack-QuickStart-Templates%2Fmaster%2Fjetstress-2013-exchange-loadtest%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

This template deploys a Jetstress workload for Exchange 2016. The Jetstress workload simulates Exchange database and find out IOPS supported by a given storage subsystem.

NOTE: Please make sure to user unique resource group name for each deployment to avoid deployment failures due to name collisions of resources.

NOTE: There is a 90 minutes Azure time-out which you can hit if large number of VMs are deployed or test duration is longer than 60 minutes.

`Tags: exchange, jetstress, workload`

| Endpoint        | Version           | Validated  |
| ------------- |:-------------:| -----:|
| Microsoft Azure      | - | yes |
| Microsoft Azure Stack      | - |  yes |


## Deployed resources

####[Jetstress Load Test]
[Deploys a VM, install Jetstress, downloads Exchange 2016 ISO to get supported binaries for Jetstress, run load test with given parameters]
+ **Public IP Address**: Allows connection to a VM
+ **Network Security Group**: 
+ **Storage Account**: VHDs, Result blobs storage
+ **Network Interface**: 
+ **Virtual Network**: 
+ **Virtual Machine**: To run Jetstress test
+ **DSC Extension**: Run Jetstress load test with Exchange 2016 binaries


## Deployment steps
You can either click the "deploy to Azure" button at the beginning of this document or deploy the solution from PowerShell with the following PowerShell script.

```PowerShell
jetstressVMCount: 2 #[Number of VMs to deploy and run jestress workload]

testExecutionTime: 60 #[Jetstress workload execution time]

numberOfThreads: AutoSeek #[Jetstress can AutoSeek # of threads required or you can provide from available options]

testType: "DiskSubsystemThroughput" #[Choose from 'DiskSubsystemThroughput' where % of storage capacity and iops capacity can be provided or 'ExchangeMailboxProfile' where number of mailbox, iops/mailbox and mailbox size can be provided]

storageDiskCapacityPercentage: 80 #[For test type 'DiskSubsystemThroughput', storage capacity percentage to occupy]

iopsCapacityPercentage: 100 #[For test type 'DiskSubsystemThroughput', iops capacity percentage to occupy]

exchangeMailboxCount: 10 #[For test type 'ExchangeMailboxProfile', number of exchange mailbox to deploy]

exchangeIopsPerMailbox: 1 #[For test type 'ExchangeMailboxProfile', number of iops per mailbox]

exchangeMailboxSizeInMB: 200 #[For test type 'ExchangeMailboxProfile', size of exchange mailbox in MBs]
```

<b>RESULTS</b>

Jestress for Exchange 2016 results file is uploaded to Unique Azure Storage Account ('uniqueStorageAccountName' variable) as a blob with name 'JetstressResult.zip'


