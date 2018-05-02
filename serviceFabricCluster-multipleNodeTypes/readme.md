This item will deploy a secured Service Fabric Cluster. For more information, see [Service Fabric Cluster Security](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-security).
# Prerequisites

1.	Cluster certificate – this is the server-side certificate. The CN on this cert needs to match the FQDN of the SF cluster being created. The cert needs to be a Pfx i.e. should contain its private key. See [requirements](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-security) for creating this server side cert.
Note: Self-signed certs can also be used for testing purposes and don’t have to match the FQDN

2.	Admin Client Certificate – this is the certificate that the client will use to authenticate to the SF cluster. This can be self-signed. See [requirements](https://docs.microsoft.com/en-us/azure/service-fabric/service-fabric-cluster-security) for creating this client cert.

3.	Windows Server 2016 image in Azure Stack Marketplace – the template uses the Windows Server 2016 image to create the cluster. You can download this from Marketplace Syndication.

# Installation Steps:
## Azure Stack Operator
- Download the Service Fabric Cluster (Preview) item from Marketplace management. 
You should now see the Marketplace item in your Azure Stack Marketplace under Compute.

![Marketplace](images/Marketplace.png)
 
 