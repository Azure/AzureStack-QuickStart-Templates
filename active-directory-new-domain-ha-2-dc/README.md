# Create 2 new Windows VMs, create a new AD Forest, Domain and 2 DCs in an availability set


## Description

This template will deploy 2 new VMs (along with a new VNet, Storage Account and Load Balancer) and create a new  AD forest and domain, each VM will be created as a DC for the new domain and will be placed in an availability set. Each VM will also have an RDP endpoint added with a public load balanced IP address.

Click the button below to deploy

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Factive-directory-new-domain-ha-2-dc%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Factive-directory-new-domain-ha-2-dc%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/AzureGov.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Factive-directory-new-domain-ha-2-dc%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

## Change

### 2019-11
- Rename original deployment to azuredeploy-unmanagedDisk.json.
- Update deployment to use managed disk for VMs. 
- Update api version based on Azure Stack build 1908.
- Update availability set to support VMs with managed disks.
- Update DSC:
  - Add xDnsServer (1.13.0.0) resource from https://github.com/PowerShell/xDnsServer. 
  - Add DNS forwarder configuration to Azure Stack DNS (168.63.129.16) for both domain controllers.

## Notice

- The disks of VM will be created during VM creation.  Deployment will be failed if there is disk with same name.  
- Need Internet access to download dependencies if starting deployment from Github Uri. 

## Known Issues

+	This template is entirely serial due to some concurrency issues between the platform agent and the DSC extension which cause problems when multiple VM and\or extension resources are deployed concurrently, this will be fixed in the near future - `fixed in managed disk deployment "azuredeploy.json" with changes 2019-11.`

+   No deployment button for Azure Stack since Azure Stack portal Uri is customerized, not standard. 
    +   `Workaround`: customize the Uri as following format:
  
        ``` 
        https://YOUR_AZURE_STACK_TENANT_URI/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fwellsluo%2FAzureStack-QuickStart-Templates%2Fwellsluo-dev%2Factive-directory-new-domain-ha-2-dc%2Fazuredeploy.json
        ```

        Example:
        ```
        https://portal.local.azurestack.contoso.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fwellsluo%2FAzureStack-QuickStart-Templates%2Fmaster%2Factive-directory-new-domain-ha-2-dc%2Fazuredeploy.json        
        ```



