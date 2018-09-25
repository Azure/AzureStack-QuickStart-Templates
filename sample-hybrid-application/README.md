Azure Stack to Azure Hybrid Connection with WebApp
==================================================

Technical guidance
------------------
Contents
========

[1 Overview](#overview)

[1.1 Context and Considerations](#context-and-considerations)

[1.2 When to Use This Pattern](#when-to-use-this-pattern)

[2 Reference Architecture](#prerequisites)

[2.1 Azure Resources](#azure-resources)

[2.2 Azure Stack Resources](#azure-stack-resources)

[3 Prerequisites](#prerequisites)

[3.1 Before you begin](#before-you-begin)

[4 Deploying Azure Stack Resources](#deploying-azure-stack-resources)

[4.1 Preparing Parameters (Azure Stack)](#preparing-parameters-azure-stack)

[4.2 Deploying Template (Azure Stack)](#deploying-template-azure-stack)

[5 Deploying Azure Resources](#deploying-azure-resources)

[5.1 Preparing Parameters (Azure)](#preparing-parameters-azure)

[5.2 Deploying Template (Azure)](#deploying-template-azure)

[6 Configuring VPN Connection](#configuring-vpn-connection)

[6.1 Azure Stack Connection Configuration](#azure-stack-connection-configuration)

[6.2 Azure Connection Configuration 14](#azure-connection-configuration)

[7 Configuring WebApp for VNET Routing](#configuring-webapp-for-vnet-routing)

[7.1 Configuring Point to Site Connection](#configuring-point-to-site-connection)

[7.2 Configuring Vnet Integration for WebApp](#configuring-vnet-integration-for-webapp)

[7.3 Syncing Routes and Cert for Appserver](#syncing-routes-and-cert-for-appserver)

[8 Troubleshooting](#_Toc524132557)

[8.1 Verifying Azure VPN tunnel](#verifying-azure-vpn-tunnel)

[8.2 Verifying WebApp Application Settings](#verifying-webapp-application-settings)

[8.3 Verifying Appsettings.Json file](#verifying-appsettings.json-file)

[8.4 WebApp Connectivity](#webapp-connectivity)

[9 Appendix](#_Toc524132557)

[9.1 Configuring BGP for Azure Stack Development Kit Only](#configuring-bgp-for-azure-stack-development-kit-only)

[9.2 Using the North Wind WebApp](#using-the-north-wind-webapp)

[9.3 Verify Data in Database](#verify-data-in-database)

# Overview

This reference article details environmental requirements and steps for
setting up Azure to Azure Stack Hybrid Connections.

Microsoft is the only cloud provider that offers a truly consistent
hybrid cloud platform, including a consistent hybrid networking
experience. Setting a hybrid connection between an Azure Virtual Network
and Azure Stack Virtual Network is simple, using the same process in
each cloud.

The hybrid network provides secure access between a virtual network in
Azure and a virtual network in Azure Stack. Endpoints in Azure,
including App Service applications linked to a virtual network, can
communicate with endpoints in Azure Stack as if they were on the same
network.

##  Context and Considerations

There are some distinctions between one-node Azure Stack Development Kit
(ASDK), and multi-node Azure Stack Integrated System (ASIS).

ASDK utilizes a public IP address, while maintaining its own VM with a
separate and defined private network.

Azure Stack Integrated System integrates with your datacenter and has an
entire IP address range to delegate to the system during installation.
This requires some specialized setup and configuration for the Azure
stack isolated environment. Software-defined networking requires only
four cables connecting an Azure Stack machine to the outside network.

##  When to Use This Pattern

**Use hybrid cloud resources to implement a Hybrid Connection**

  - Hybrid Connectivity is a foundational pattern that allows you
    securely access resources in an Azure Stack deployment from Azure.

  - Certain data must live on-premises because of privacy or regulatory
    requirements.

  - Maintain a legacy system while utilizing cloud-scaled app
    deployment.

# Prerequisites

**Azure Stack**

  - Firewall and or router appliance needs to know how to route traffic
    to and from Azure Stack environment

  - An Azure Stack Environment.
    
    For information on how to deploy Azure Stack Development Kit see
    [ASDK-Install](https://docs.microsoft.com/azure/azure-stack/asdk/asdk-install)

  - Azure Stack environment has SQLRP deployed and configured.
    
    For information on how to deploy Azure Stack Development Kit see
    [Azure
    Stack-SQL-Resource-Provider-Deploy](https://docs.microsoft.com/azure/azure-stack/azure-stack-sql-resource-provider-deploy)

  - SQL Server 2016 image added to your Azure Stack Marketplace.
    
    For information on how to add Marketplace images from Azure
    Marketplace see
    [Adding-Images](https://docs.microsoft.com/azure/azure-stack/asdk/asdk-register)

  - Plans, Offers and Quotas Configured.
    
    For information on how to configure Quotas, Offers and Plans see
    [Plan-Offer-Quota-Overview](https://docs.microsoft.com/azure/azure-stack/azure-stack-plan-offer-quota-overview)

  - A tenant subscribed to your Azure Stack Offer/Plan.
    
    For information on how to Subscribe to an offer see.
    [Subscribe-to-an-Offer](https://docs.microsoft.com/azure/azure-stack/azure-stack-subscribe-plan-provision-vm)

**Azure**

  - An Azure Subscription

> If you don't have an Azure subscription, create a [free
> account](https://azure.microsoft.com/free/?WT.mc_id=A261C142F) before
> you begin.

  - The Azure user needs to have a GitHub Account linked to email

  - The Azure user needs to have access to the GitHub Repository
    
    For information on how to add Collaborators see
    [Adding-Collaborators](https://help.github.com/articles/inviting-collaborators-to-a-personal-repository/)

  - You must approve a connection from Azure to GitHub before you begin
    the deployment. This can be accomplished by manually creating a
    WebApp from the Azure portal, clicking on the Deployments options
    and setting up the access to the GitHub repository.

##  Before you begin

Verify that you have met the following criteria before beginning your
configuration:

  - Verify that you have an externally facing public IPv4 address for
    your VPN device. This IP address cannot run through network
    address translation (NAT).

  - Ensure all resources are deployed in the same region/location.

For more information about VPN Gateway settings in general, see [About
VPN Gateway
Settings](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings).

**Note: If you are using an ASDK environment please Complete Appendix
Section 9.1**

# Reference Architecture

This section details the reference architecture that can be used as a
guidance to implement the offer.

<img src="Hybrid-Deployment\ref_architecture.jpg" />

This architecture consists of the following components:

## Azure Resources

  - **Azure App Services**. Build, deploy, and scale enterprise-grade
    web, mobile, and serverless compute applications and as well as
    leveraging RESTful APIs running on any platform with
    Platform-as-a-service (PaaS) offerings. For more information about
    Azure App Services see [Microsoft Azure App Services
    Overview](https://azure.microsoft.com/en-us/services/app-service/).

  - **Azure Virtual Network.** [Azure Virtual
    Network](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview)
    enables many types of Azure resources, such as Azure Virtual
    Machines (VM), to securely communicate with each other, the
    internet, and on-premises networks.
    
      - **Application Subnet.** Dividing the Azure Virtual Network into
        two or more logical, IP subdivisions via subnets provides a
        custom private IP address space using public and private (RFC
        1918) addresses. This subnet will be where many of the resources
        will be deployed.
    
    <!-- end list -->
    
      - **Gateway Subnet.** The gateway subnet is part of the virtual
        network IP address range specified when configuring the virtual
        network, and contains the IP addresses that the [virtual network
        gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-create-site-to-site-rm-powershell)
        resources and services use.

<!-- end list -->

  - **Azure Local Network Gateway.** The local network gateway typically
    refers to the on-premises location. Azure refers to the site name
    and specifies the IP address of the local VPN device to connect to.

<!-- end list -->

  - **Azure Virtual Network Gateway.** The Azure Virtual Network Gateway
    acts as a [Site-to-Site VPN
    gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings)
    connection that is used to connect the on-premises network to an
    Azure virtual network over an IPsec/IKE (IKEv1 or IKEv2) VPN tunnel.

  - **Azure Public IP.** [Public IP
    addresses](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-ip-addresses-overview-arm#public-ip-addresses)
    allow Internet resources to communicate inbound to Azure resource,
    and enable Azure resources to communicate outbound to Internet and
    public-facing Azure services with an IP address assigned to the
    resource.

  - **Azure Point to Site Application VPN.** A [Point-to-Site
    (P2S)](https://docs.microsoft.com/en-us/azure/vpn-gateway/point-to-site-about)
    VPN connection allows a secure connection to the virtual network
    from an individual client computer. This solution is useful for
    telecommuters needing to connect to Azure VNets from a remote
    location.

##  Azure Stack Resources

  - **Azure Stack IaaS for Hosting a Microsoft SQL Server VM.** Use the
    same application model, self-service portal, and APIs enabled by
    Azure. [Azure Stack
    IaaS](https://azure.microsoft.com/en-us/overview/azure-stack/benefits/)
    allows for a broad range of open source technologies for consistent
    hybrid cloud deployments.

  - **Azure Stack Virtual Network.** The Azure Stack Virtual Network,
    works exactly like the [Azure Virtual
    Network](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview),
    and enables many types of Azure resources, such as Azure Virtual
    Machines (VM), to securely communicate with each other, the
    internet, and on-premises networks.
    
      - **Application Subnet.** Dividing the Azure Virtual Network into
        two or more logical, IP subdivisions via subnets provides a
        custom private IP address space using public and private (RFC
        1918) addresses. This subnet will be where the majority of the
        resources will be deployed.
    
      - **Gateway Subnet.** The gateway subnet is part of the virtual
        network IP address range specified when configuring the virtual
        network, and contains the IP addresses that the [virtual network
        gateway](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-create-site-to-site-rm-powershell)
        resources and services use.

  - **Azure Stack Virtual Network Gateway.** Send network traffic
    between Azure virtual network and an on-premises site by creating a
    [virtual network
    gateway.](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-vpn-gateway-about-vpn-gateways)

  - **Azure Stack Local Network Gateway.** [The local network gateway
    typically refers to the on-premises location. Azure refers to the
    site name and specifies the IP address of the local VPN device to
    connect to.
    ](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-network)

**Azure Stack Public IP.** The Azure Stack [Public IP
addresses](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-ip-addresses-overview-arm#public-ip-addresses)
work like the Azure Public IP addresses, allowing Internet resources to
communicate inbound to Azure resource, and enable Azure resources to
communicate outbound to Internet and public-facing Azure services with
an IP address assigned to the resource. As note, please work with the
Hardware OEM Partners to make Azure Stack services (such as the portals,
Azure Resource Manager, DNS, etc.) available to external networks.

# Deploying Azure Stack Resources

In This section you will provision all the necessary resources required
to create a Site-to-Site connection between Azure Stack and Azure. The
resources deployed are as follows:

  - VM’s (All associated resources i.e. NIC’s, Public IP Addresses,
    V-Net, etc.)

  - Network Security Groups

  - Standard Storage Account

  - Local Network Gateway

  - Virtual Network Gateway

  - Connection

##  Preparing Parameters (Azure Stack)

<table>
<thead>
<tr class="header">
<th>Step</th>
<th>Step Details</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>1</td>
<td>Download the Hybrid project and save it your local machine</td>
</tr>
<tr class="even">
<td>2</td>
<td><p>Navigate to the <strong>Azurestackdeploy.paramaters.json</strong> file</p>
<p>It is located in the <strong>Hybrid-AzureStack</strong> folder</p></td>
</tr>
<tr class="odd">
<td>3</td>
<td>Fill in <strong>Parameter</strong> <strong>values</strong>. Below is a description of the parameters</td>
</tr>
</tbody>
</table>

<table>
<thead>
<tr class="header">
<th>Parameter</th>
<th>Description</th>
<th>Value</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td></td>
<td></td>
<td></td>
</tr>
<tr class="even">
<td>dnsNameForPublicIP</td>
<td>FQDN for Virtual Machine.</td>
<td>Ener a Value</td>
</tr>
<tr class="odd">
<td>AddressPrefix</td>
<td>Virtual Network IP Range</td>
<td><p>10.100.100.0/22</p>
<p>If you enter your own values make sure they do not overlap with your Azure Network Range</p></td>
</tr>
<tr class="even">
<td>Subnet</td>
<td>Network subnet IP Range (Must be inline with Virtual Network Range)</td>
<td>10.100.100.0/24</td>
</tr>
<tr class="odd">
<td>GatewaySubnet</td>
<td>Network subnet for Virtual Network gateway (Must be inline with Virtual Network Range</td>
<td>10.100.101.0/24</td>
</tr>
<tr class="even">
<td>LocalGatewayIPAddress</td>
<td>IP Address of you Azure Gateway Public IP</td>
<td>Leave this value as is. You will not get this value until you deploy your azure resources.</td>
</tr>
<tr class="odd">
<td>LocalGatewayAddressPrefix</td>
<td>The Network IP Address range in your Azure Environment</td>
<td>10.100.104.0/22</td>
</tr>
<tr class="even">
<td>baseURL</td>
<td></td>
<td>leave blank as this value gets populated and updated automatically after running script.</td>
</tr>
</tbody>
</table>

##  Deploying Template (Azure Stack)

<table>
<thead>
<tr class="header">
<th>Step</th>
<th>Step Details</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>1</td>
<td>Open a <strong>PowerShell ISE</strong> window as an <strong>Administrator</strong> and navigate to the <strong>hybrid-Deployment Directory</strong></td>
</tr>

<tr class="odd">
<td>2</td>
<td><p>Now run the <strong>Deploy-SolutionAzureStack.ps1</strong> with the following parameters</p>
<p>.\Deploy-SolutionAzureStack.ps1 -rg {enterValue} -presharedkey {enterValue} -storageAccount<span id="Resourcegroup_4_2" class="anchor"></span>Name {enterValue} -targetStorageContainer {enterValue} -location {enterValue} -tenantID {enterValue} -azureStackArmEndpoint {enterValue} -Verbose</p>
<p>.\Deploy-SolutionAzureStack.ps1 -rg {enterValue} -presharedkey {enterValue} -storageAccountName {enterValue} -targetStorageContainer {enterValue} -AADTenantName {enterValue} -azureStackArmEndpoint {enterValue} -Verbose</p></td>
</tr>
<tr class="even">
<td>3</td>
<td>You will be prompted to enter <strong>Credentials</strong>. This will be the credentials for your <strong>Azure Stack Tenant Subscription</strong></td>
</tr>
<tr class="odd">
<td>4</td>
<td>You will get progress output periodically</td>
</tr>
<tr class="even">
<td>5</td>
<td><p>After your Azure Stack Resources have been deployed you will be prompted to <strong>Update Local Network Gateway. </strong></p>
<p>At this point please Minimize the PowerShell ISE window. </p></td>
</tr>
<tr class="odd">
<td>6</td>
<td><strong>We need to get IP value from section 5.2 before we resume deployment</strong></td>
</tr>
</tbody>
</table>

# Deploying Azure Resources

In This section you will provision all the necessary resources required
to create a Site-to-Site connection between Azure and Azure Stack. The
resources deployed are as follows:

  - WebApp

  - App Insights

  - Network Security Groups

  - Local Network Gateway

  - Virtual Network
Gateway

  - Connection

## Preparing Parameters (Azure)

| Step | Step Details                                                                                                       | 
| ---- | ------------------------------------------------------------------------------------------------------------------ | 
| 1    | Navigate to **Hybrid-Deployment\\Hybrid-Azure** folder as we need to edit the **Azuredeploy.paramaters.json file** | 
| 2    | Edit the Highlighted values. Below is a table with the **parameter** descriptions.                                 | 

<table>
<thead>
<tr class="header">
<th>Parameter</th>
<th>Description</th>
<th>Value</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>AddressPrefix</td>
<td>Virtual Network IP Range</td>
<td><p>10.100.104.0/22</p>
<p>If you enter your own values make sure they do not overlap with your Azure Stack Network Range</p></td>
</tr>
<tr class="even">
<td>Subnet</td>
<td>Network subnet IP Range (Must be inline with Virtual Network Range)</td>
<td>10.100.104.0/24</td>
</tr>
<tr class="odd">
<td>GatewaySubnet</td>
<td>Network subnet for Virtual Network gateway (Must be inline with Virtual Network Range</td>
<td>10.100.105.0/24</td>
</tr>
<tr class="even">
<td>LocalGatewayIPAddress</td>
<td>External Facing IP Address, cannot be behind NAT</td>
<td>Enter value</td>
</tr>
<tr class="odd">
<td>SiteName</td>
<td>Name of your Website which is hosted on your WebApp Server</td>
<td>Enter value</td>
</tr>
<tr class="even">
<td>HostingPlanName</td>
<td>Name or your WebApp Server</td>
<td>Enter value</td>
</tr>
<tr class="odd">
<td>EnvrinmentName</td>
<td>Name for the Environment which is Hosting your Isolated Web App Server</td>
<td>Enter value</td>
</tr>
<tr class="even">
<td>repoURL</td>
<td>This is the URL where the Hybrid Deployment project accessed</td>
<td>Enter Value</td>
</tr>
</tbody>
</table>

##  Deploying Template (Azure)

<table>
<thead>
<tr class="header">
<th>Step</th>
<th>Step Details</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>1</td>
<td>Open a PowerShell window as Administrator and navigate to the <strong>hybrid-Deployment Directory</strong></td>
</tr>
<tr class="even">
<td>2</td>
<td><p>Now run the <strong>Deploy-SolutionAzure.ps1</strong> with the following parameters:</p>
<p>.\Deploy-SolutionAzureStack.ps1 -rg {enterValue} - -presharedkey {enterValue} -ADAppPassword {enterValue} -emailNotification {enterValue} -Verbose</p>
<strong>Be sure to use the same preshared key value used earlier</strong></td>
</tr>
<tr class="even">
<td>3</td>
<td>You will be prompted to enter <strong>Credentials</strong>. This will be the credentials for your <strong>Azure Subscription</strong></td>
</tr>
<tr class="odd">
<td>4</td>
<td>You will get progress output periodically</td>
</tr>
<tr class="even">
<td>5</td>
<td><p><span id="IP_5_2" class="anchor"></span>Once Azure resources are deployed you will be prompted to Change Values of your Local Network Gateway in Azure Stack</p>
<p><strong>Copy</strong> this value as we are going to use it in a later section</p>
<p>At this point please minimize the PowerShell window. </p></td>
</tr>
</tbody>
</table>

# Configuring VPN Connection 

In this Section we will configure our Local Network Gateways with the
outputted values given from both the PowerShell ISE and PowerShell
windows.

##  Azure Stack Connection Configuration

<table>
<thead>
<tr class="header">
<th>Step</th>
<th>Step Details</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>1</td>
<td>Log into your <strong>Azure Stack Portal</strong></td>
</tr>
<tr class="even">
<td>2</td>
<td><p>Navigate to the resource group created in <a href="#Resourcegroup_4_2">Step 2 in Section 4.2</a></p>
<p>Click on the <strong>Local Network Gateway</strong> icon</p></td>
</tr>
<tr class="odd">
<td>3</td>
<td>Click on the <strong>Configurations</strong> tab</td>
</tr>
<tr class="even">
<td>4</td>
<td><p>Paste the value of IP address given in <a href="(#azure-connection-configuration)">Section 5.2 step 6</a></p>
<p>And Click <strong>Save</strong></p></td>
</tr>
<tr class="odd">
<td>5</td>
<td><p>Navigate back to your <strong>PowerShell ISE window</strong></p>
<p><strong>Be sure that it is the ISE Window that is associated to your Azure Stack</strong></p>
<p><strong>Press</strong> <strong>Any Key to Continue</strong></p></td>
</tr>
<tr class="even">
<td>6</td>
<td><p>Once you see that <span id="IP_6_1" class="anchor"></span>the <strong>Connection</strong> has <strong>succeeded</strong></p>
<p>Copy the Value as we will need this for the next section</p></td>
</tr>
</tbody>
</table>

##  Azure Connection Configuration

<table>
<thead>
<tr class="header">
<th>Step</th>
<th>Step Details</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>1</td>
<td>Log into <strong>Azure Public Portal</strong></td>
</tr>
<tr class="even">
<td>2</td>
<td><p>Navigate to the resource group created in <a href="#AzureStack_RG">Step 2 in Section 5.2</a></p>
<p>Click on the <strong>Local Network Gateway</strong> icon</p></td>
</tr>
<tr class="odd">
<td>3</td>
<td>Click on the <strong>Configurations</strong> tab</td>
</tr>
<tr class="even">
<td>4</td>
<td><p>Paste the value of IP address given in <a href="#IP_6_1">Section 6.1 Step 6</a></p>
<p>And Click <strong>Save</strong></p></td>
</tr>
<tr class="odd">
<td>5</td>
<td>After pressing Enter you should see a <strong>provisioning State Succeeded</strong> you have now completed the VPN Connection between <strong>Azure and Azure Stack</strong></td>
</tr>
</tbody>
</table>

# Configuring WebApp for VNET Routing 

A common scenario where you would use VNet Integration is enabling
access from your web app to a database or a web service running on a
virtual machine in your Azure virtual network. With VNet Integration,
you don't need to expose a public endpoint for applications on your VM
but can use the private non-internet routable addresses instead.

The VNet Integration feature:

  - > Requires a Standard, Premium, or Isolated pricing plan

  - > Works with Classic or Resource Manager VNet

  - > Supports TCP and UDP

  - > Works with Web, Mobile, API apps and Function apps

  - > Enables an app to connect to only 1 VNet at a time

  - > Enables up to five VNets to be integrated with in an App Service
    > Plan

  - > Allows the same VNet to be used by multiple apps in an App Service
    > Plan

  - > Supports a 99.9% SLA due to the SLA on the VNet Gateway

There are some things that VNet Integration does not support, including:

  - > mounting a drive

  - > AD integration

  - > NetBios

  - > private site access

Here are some things to keep in mind before connecting your web app to a
virtual network:

  - > VNet Integration only works with apps in a **Standard**,
    > **Premium**, or **Isolated** pricing plan. If you enable the
    > feature, and then scale your App Service Plan to an unsupported
    > pricing plan your apps lose their connections to the VNets they
    > are using.

  - > If your target virtual network already exists, it must have
    > point-to-site VPN enabled with a Dynamic routing gateway before it
    > can be connected to an app. If your gateway is configured with
    > Static routing, you cannot enable point-to-site Virtual Private
    > Network (VPN).

  - > The VNet must be in the same subscription as your App Service
    > Plan(ASP).

  - > If your gateway already exists with point-to-site enabled, and it
    > is not in the basic SKU, IKEV2 must be disabled in your
    > point-to-site configuration.

  - > The apps that integrate with a VNet use the DNS that is specified
    > for that VNet.

  - > By default your integrating apps only route traffic into your VNet
    > based on the routes that are defined in your VNet.

##  Configuring Point to Site Connection

In this section we will need to configure our routes between our Azure
and Azure Stack Networks. This is done by configuring the VNET Routing.

<table>
<thead>
<tr class="header">
<th>Step</th>
<th>Step Details</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>1</td>
<td>Log into your Azure Subscription. Then navigate to your Virtual Network Gateway.</td>
</tr>
<tr class="even">
<td>2</td>
<td>Click on <strong>Point-to-Site Configuration</strong>.</td>
</tr>
<tr class="odd">
<td>3</td>
<td>Click on <strong>Configure Now</strong></td>
</tr>
<tr class="even">
<td>4</td>
<td><p>Under Address Pool. Enter <strong>172.16.0.0/24</strong></p>
<p><span id="Vnet_7_1" class="anchor"></span></p>
<p><strong>Be sure that SSL</strong> <strong>VPN</strong> <strong>is checked</strong></p>
<p>And Click <strong>Save </strong></p></td>
</tr>
</tbody>
</table>

##  Configuring VNET Integration for WebApp

<table>
<thead>
<tr class="header">
<th>Step</th>
<th>Step Details</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>1</td>
<td>Navigate to your resource group window and Click on your <strong>WebApp</strong></td>
</tr>
<tr class="even">
<td>2</td>
<td>Scroll down and Click on <strong>Network</strong></td>
</tr>
<tr class="odd">
<td>3</td>
<td>Click <strong>Setup</strong></td>
</tr>
<tr class="even">
<td>4</td>
<td>Chose <strong>myVnet</strong></td>
</tr>
<tr class="odd">
<td>5</td>
<td><p>Getting a Failure is expected. If you refresh the page. You will see that your <strong>VNET integration</strong> is in a <strong>Connected</strong> state</p></td>
</tr>
</tbody>
</table>

##  Syncing Routes and Cert for Appserver

<table>
<thead>
<tr class="header">
<th>Step</th>
<th>Step Details</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>1</td>
<td>Navigate to your resource group window and Click on your <strong>AppServer</strong></td>
</tr>
<tr class="even">
<td>2</td>
<td>Scroll down and Click on <strong>Network</strong></td>
</tr>
<tr class="odd">
<td>3</td>
<td>Click <strong>Manage</strong></td>
</tr>
<tr class="even">
<td>4</td>
<td>Click on <strong>myVnet</strong></td>
</tr>
<tr class="odd">
<td>5</td>
<td>Next Click on Sync Network. Then click <strong>Yes</strong></td>
</tr>
<tr class="even">
<td>6</td>
<td><p>A Cmak error is expected here.</p>
<p>This happens because of the IKEv2 and External Radius Settings configured in <a href="#Vnet_7_1">Section 7.1</a></p></td>
</tr>
<tr class="odd">
<td>6</td>
<td><p>In your PowerShell Window (the one Connected to Azure public)</p>
<p><strong>Type</strong> <strong>.\cmak_error_fix.ps1</strong></td>
</tr>
<tr class="odd">
<td>7</td>
<td>Enter Azure Credentials</td>
</tr>
<tr class="even">
<td>8</td>
<td>Once the script is finished running, Go back to your <strong>Azure Public Portal</strong>.</td>
</tr>
<tr class="odd">
<td>9</td>
<td>Clear all <strong>notifications</strong></td>
</tr>
<tr class="even">
<td>10</td>
<td>Now try <strong>Syncing Network</strong> again</td>
</tr>
<tr class="odd">
<td>11</td>
<td>Click <strong>Yes</strong></td>
</tr>
<tr class="even">
<td>12</td>
<td>You should now see 3 green Check Marks stating that <strong>Certificates, routes and Data</strong> have initialized a sync. You have now successfully configured routes between your <strong>Azure and Azure Stack</strong> Networks.</td>
</tr>
</tbody>
</table>

##  Add DNS Host Name to Azure Stack Web App

| Step | Step Details                                                                 |
| ---- | ---------------------------------------------------------------------------- |
| 1    | Navigate to your Azure Stack portal and click on WebApp                      |
| 2    | Click on Custom Domains Tab                                                  |
| 3    | Click on Add HostName                                                        |
| 4    | Paste value outputted in the Powersehll window with traffic manager endpoint |
| 5    | Click on Add Host Name                                                       |
| 6    | Then in the PowerShell Window hit enter to continue                          |

##  Getting Key Secrets

<table>
<thead>
<tr class="header">
<th>Step</th>
<th>Step Details</th>
</tr>
</thead>
<tbody>
<tr class="even">
<td>1</td>
<td>Click on App Registration</td>
</tr>
<tr class="odd">
<td>2</td>
<td>Click on App Registration</td>
</tr>
<tr class="even">
<td>3</td>
<td>Click on Add HostName</td>
</tr>
<tr class="odd">
<td>4</td>
<td><p>Locate the “Trigger” app and click on it</p>
<p>Note: You might have to switch drop down box to All Apps</p></td>
</tr>
<tr class="even">
<td>5</td>
<td>Click On Keys</td>
</tr>
<tr class="odd">
<td>6</td>
<td>Enter a Name under Description change expiration to 2 years and Click Save</td>
</tr>
<tr class="even">
<td>7</td>
<td><p>Copy And Paste the Secret given to you into the Power Shell window</p>
<p>Be Sure not to Close Window without Copying as you will not see this Secret Again</p></td>
</tr>
<tr class="odd">
<td>8</td>
<td>Once you have pasted the Secret in PowerShell press Enter</td>
</tr>
</tbody>
</table>

##  Upload Files to Azure Function

<table>
<thead>
<tr class="header">
<th><span id="_Toc524132557" class="anchor"></span>Step</th>
<th>Step Details</th>
</tr>
</thead>
<tbody>
<tr class="header">
<td>1</td>
<td>Navigate to your Function Web App</td>
</tr>
<tr class="odd">
<td>2</td>
<td>Click on Http Trigger</td>
</tr>
<tr class="even">
<td>3</td>
<td>On the Right Column click on View Files</td>
</tr>
<tr class="odd">
<td>4</td>
<td><p>Here we need to replace the files in this App with the file located in</p>
<p>.\cross-cloud-scale\httpTrigger</p></td>
</tr>
<tr class="even">
<td>5</td>
<td>Upload One By One overwriting files</td>
</tr>
</tbody>
</table>

# Appendix

## Configuring BGP for Azure Stack Development Kit Only

<table>
<thead>
<tr class="header">
<th>Step</th>
<th>Step Details</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>1</td>
<td>Log in to the Azure Stack physical host for your ASDK</td>
</tr>
<tr class="even">
<td>2</td>
<td><p>From the Hyper-V Manager Console</p>
<p>Click the VM, say, <strong>AZS-BGPNAT01</strong> </p>
<p>On the lower window click on Networking tab</p>
<p>Take note of the IP address for the NAT Adapter that uses the PublicSwitch</p></td>
</tr>
<tr class="odd">
<td>3</td>
<td>Right Click <strong>AZS-BGPNAT01</strong> and click <strong>Connect</strong> button</td>
</tr>
<tr class="even">
<td>4</td>
<td>Sign into VM</td>
</tr>
<tr class="odd">
<td>5</td>
<td><p>Verify that IP’s match by typing ipconfig /all</p>
<p>One of your IP addresses should match to the value from the Networking Tab in previous step</p></td>
</tr>
<tr class="even">
<td>6</td>
<td><p>In the command prompt type</p>
<p><strong>Start PowerShell</strong></p>
<p>And press <strong>Enter</strong></p></td>
</tr>
<tr class="odd">
<td>7</td>
<td><p>Enter the PowerShell command</p>
<p>To designate the external NAT address for the ports that the IKE Authentication tunnel will use. </p>
<p>Remember to change the IP Address to the <strong>values taken from</strong> <a href="#verifying-azure-vpn-tunnel">Section 8.1 step 2</a></p></td>
</tr>
<tr class="even">
<td>8</td>
<td><p>Enter the PowerShell command</p>
<p>Create a static NAT mapping to map the external address to the Gateway Public IP Address.</p>
<p>This maps the ISAKMP port 500 for PHASE 1 of the IPSEC tunnel</p>
<p>Add-NetNatStaticMapping -NatName BGPNAT -Protocol UDP -ExternalIPAddress 10.16.169.131 -InternalIPAddress 192.168.102.1 -ExternalPort 500 -InternalPort 5</p></td>
</tr>
<tr class="odd">
<td>9</td>
<td><p>Finally, we will need to do NAT traversal which uses port 4500 to successfully establish the complete IPSEC tunnel over NAT devices</p>
<p>Add-NetNatStaticMapping -NatName BGPNAT -Protocol UDP -ExternalIPAddress 10.16.169.131 -InternalIPAddress 192.168.102.1 -ExternalPort 4500 -InternalPort 4500</p></td>
</tr>
<tr class="even">
<td>10</td>
<td><p>If you run a Get-NetNatExternalAddress -Natname BGPNAT</p>
<p>You should see similar results</p>
<p>Get-NetNatExternalAddress -Natname BGPNAT</p></td>
</tr>
</tbody>
</table>

## Using the North Wind WebApp

| Step | Step Details                                                                                                                          |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| 1    | Navigate to your website, on the landing page Fill out dummy information and click the **Show Plans** Button                           |
| 2    | On the **Plans page** choose an option by clicking **Buy Now**                                                                        |
| 3    | On the **Apply for a Plan** Page fill out dummy information and click **Submit Application**<span id="sql_8_2" class="anchor"></span> |
| 4    | You should now receive a **Confirmation Code**                                                                                        |

## Verify Data in Database

<table>
<thead>
<tr class="header">
<th>Step</th>
<th>Step Details</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>1</td>
<td>From your Azure Stack host remote to your SQLVM</td>
</tr>
<tr class="even">
<td>2</td>
<td>Open SQL Server Management Studio</td>
</tr>
<tr class="odd">
<td>3</td>
<td><p>Log into your SQL Server, Expand</p>
<p>Northwinddb, Tables, Right-Click and chose “Select Top 1000 rows”</p></td>
</tr>
<tr class="even">
<td>4</td>
<td>The result of the Query should show the Person created in <a href="#sql_8_2">Step 3 Section 8.2</a></td>
</tr>
</tbody>
</table>

# Troubleshooting 

##  Verifying Azure VPN tunnel

In this section we will go over the steps needed to verify deployment.

<table>
<thead>
<tr class="header">
<th>Step</th>
<th>Step Details</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>1</td>
<td><p>Log into your Azure (Public) portal</p>
<p><strong>http://Portal.azure.com</strong></p>
<p>Navigate to the recent created <strong>connection,</strong> you should now see a “<strong>Connected</strong>” status</p>
<p>Below are screen grabs of both Azure and Azure Stack Connections</p></td>
</tr>
<tr class="odd">
<td>2</td>
<td><p>Log into your Azure Stack Tenant portal</p>
<p>Navigate to the recent created <strong>connection,</strong> you should now see a “<strong>Connected</strong>” status</p></td>
</tr>
</tbody>
</table>

##  Verifying WebApp Application Settings

<table>
<thead>
<tr class="header">
<th>Step</th>
<th>Step Details</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>1</td>
<td>Click on your Web app</td>
</tr>
<tr class="even">
<td>2</td>
<td>Click the <strong>Application Settings</strong> Tab and verify that the value of your connection string</td>
</tr>
<tr class="odd">
<td>3</td>
<td><p><strong>Connection String Name</strong> = SQLWM</p>
<p><strong>Value</strong> = Data Source<strong>={Internal IP Address of SQLVM}</strong>,1433;Initial Catalog=NorthwindDb;User ID<strong>={Name used for adminUsername in Paramters}</strong>;Password<strong>={value of adminPassword in Paramters</strong>}Asynchronous Processing=True</p>
<p><strong>Type</strong> = SQLServer</p></td>
</tr>
</tbody>
</table>

##  Verifying Appsettings.Json file

<table>
<thead>
<tr class="header">
<th>Step</th>
<th>Step Details</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>1</td>
<td>Scroll down and Click on <strong>Advanced Tools</strong>, then Click <strong>Go</strong></td>
</tr>
<tr class="even">
<td>2</td>
<td>From Kudu Window Click on <strong>Debug Console</strong>, then on <strong>CMD</strong></td>
</tr>
<tr class="odd">
<td>3</td>
<td>Click On <strong>Site,wwwroot,</strong> then the P<strong>encil icon</strong> to the left of the <strong>appsettings.json file</strong></td>
</tr>
<tr class="even">
<td>4</td>
<td>Verify that the Default <strong>connection</strong> <strong>string</strong> matches the <strong>value</strong> displayed in <a href="(#configuring-point-to-site-connection">Step 2 of Section 7.1</a></td>
</tr>
<tr class="odd">
<td>5</td>
<td><p>Verify that the <strong>App insights</strong> <strong>value</strong> matches.</p>
<p>You can see the value of <strong>App insights f</strong>rom the <strong>Portal.</strong></p>
<p>See next step to validate</p></td>
</tr>
<tr class="even">
<td>6</td>
<td>From the Azure Portal <strong>click App Insights Icon</strong>, <strong>Instrumentation Key</strong> is on the top right of window</td>
</tr>
</tbody>
</table>

## WebApp Connectivity

<table>
<thead>
<tr class="header">

<th>Step Details</th>
</tr>
</thead>
<tbody>
<tr class="odd">

<td><p>Next use Tcpping to check connectivity between the WebApp and SQLVM using port 1433</p>
<p>In the lower window type:</p>
<p>Tcpping <strong>10.00.100.4:1433</strong></p>
<p>>You should get a successful response</p>
<p><strong>Note: </strong>If you are following guidance using default values enter the above IP Address.</p>
<p><strong>If you used other network segments in deployment use the value of SQLIP in the test.csv file located in the Root folder of Hybrid-Deployment with a :1433</strong></p></td>
</tr>
</tbody>
</table>
