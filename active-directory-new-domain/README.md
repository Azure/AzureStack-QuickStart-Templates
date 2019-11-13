# Create a new Windows VM and create a new AD Forest, Domain and DC


## Description
This template will deploy a new VM (along with a new VNet and Load Balancer) and will configure it as a Domain Controller and create a new forest and domain.

Last update on 2019/11/08.

## Components
- 1 Virtual Machine as Active Directory Domain Service domain controller.
  - Default VM size: Standard_DS2_v2
  - OS: Windows Server 2019 Datacenter
  - 1 Nic with static virtual network IP Address: 10.0.0.4
  - 1 OS disk and 1 Data disk - Managed Disks. 
- 1 Public Load Balancer.
- 1 Public IP address (VIP).
- 1 Virtual Network.
  - IP Range: 10.0.0.0/16
  - 1 subnet: 10.0.0.0/24
  - DNS: 10.0.0.4
- 1 Availability Set for virtual machine.


## Deployment
Click the button below to deploy

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fwellsluo%2FAzureStack-QuickStart-Templates%2Fwellsluo-dev%2Factive-directory-new-domain%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fwellsluo%2FAzureStack-QuickStart-Templates%2Fwellsluo-dev%2Factive-directory-new-domain%2Fazuredeploy.json" target="_blank">
    <img src="https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.png"/>
</a>

## Known issue

+ No external FQDN resolving since the DNS server is currently pointed to the DNS Server in Domain Controller.  Workaround: manually add DNS forwarder in DNS Server management console, point to a DNS which can resolve external FQDN, Azure DNS is an option: 168.63.129.16.