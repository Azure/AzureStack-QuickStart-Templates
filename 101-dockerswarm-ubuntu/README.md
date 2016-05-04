# Clusters with Swarm Orchestrators

These Microsoft Azure Stack templates create various cluster Swarm Orchestrators.

Note:This version of swarm deployment USING ADMIN PASSWORD. SSHKeys are not supported at this moment The below content is to give overall architecture of the Swarm Cluster

## Deployed resources

 Once your cluster has been created you will have a resource group containing 2 parts:

 1. a set of 1,3,5 masters in a master specific availability set.  Each master's SSH can be accessed via the public dns address at ports 2200..2204

 2. a set of agents behind in an agent specific availability set.  The agent VMs must be accessed through the master.

  The following image is an example of a cluster with 3 masters, and 3 agents:

 ![Image of Swarm cluster on azure](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/master/101-dockerswarm-ubuntu/images/swarm.png)

 All VMs are on the same private subnet, 10.0.0.0/18, and fully accessible to each other.
## Prerequisites

Follow the below links to create an Ubuntu Image and upload the same to Azure Stack's Platform Image Repository
1. https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-linux-create-upload-ubuntu/ 
2. https://azure.microsoft.com/en-us/documentation/articles/azure-stack-add-image-pir/

## Deployment steps
=> Deploy to azurestack, using custom deployment in azurestack portal.
=> or use Deployswarm.ps1 to deploy to azurestack via powershell.

## Template Parameters
When you launch the installation of the cluster, you need to specify the following parameters:
* `adminPassword`: self-explanatory
* `agentCount`: the number of swarm Agents that you want to create in the cluster.  You are allowed to create 1 to 10 agents
* `masterCount`: Number of Masters. Currently the template supports 3 configurations: 1, 3 and 5 Masters cluster configuration.
* `agentVMSize`: The type of VM that you want to use for each node in the cluster. The default size is A1 but you can change that if you expect to run workloads that require more RAM or CPU resources.

## Usage
1. Get your endpoints to cluster
 1. browse to https://portal.azurestack.local

 2. then click browse all, followed by "resource groups", and choose your resource group

 ![Image of resource groups in portal](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/master/101-dockerswarm-ubuntu/images/portal-resourcegroups.png)

 3. then expand your resources, and copy the dns names of your jumpbox (if chosen), and your NAT public ip addresses.

 ![Image of public ip addresses in portal](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/master/101-dockerswarm-ubuntu/images/portal-publicipaddresses.png)

2. Connect to your cluster using windows jumpbox - remote desktop to the windows jumpbox 

## Explore Swarm with Simple hello world
 1. After successfully deploying the template write down the two output master and agent FQDNs.
 2. SSH to port 2200 of the master FQDN
 3. Type `docker -H 10.0.0.5:2375 info` to see the status of the agent nodes.
 ![Image of docker info](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/master/101-dockerswarm-ubuntu/images/dockerinfo.png)
 4. Type `docker -H 10.0.0.5:2375 run hello-world` to see the hello-world test app run on one of the agents

## Explore Swarm with a web-based Compose Script, then scale the script to all agents
 1. After successfully deploying the template write down the two output master and agent FQDNs.
 2. create the following docker-compose.yml file with the following content:
```
web:
  image: "yeasy/simple-web"
  ports:
    - "80:80"
  restart: "always"
```
 3.  type `export DOCKER_HOST=10.0.0.5:2375` so that docker-compose automatically hits the swarm endpoints
 4. type `docker-compose up -d` to create the simple web server.  this will take about a minute to pull the image
 5. once completed, type `docker ps` to see the running image.
 ![Image of docker ps](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/master/101-dockerswarm-ubuntu/images/dockerps.png)
 6. You can now scale the web application by typing `docker-compose scale web=3`, and this will scale to the rest of your agents.  The Azure load balancer will automatically pick up the new containers.
 ![Image of docker scaling](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/master/101-dockerswarm-ubuntu/images/dockercomposescale.png)

 ## Notes
 * the installation log for the linux jumpbox, masters, and agents are in /var/log/azure/cluster-bootstrap.log
 * event though the VMs finish quickly configuring swarm can take 5-15 minutes to install, check /var/log/azure/cluster-bootstrap.log for the completion status.

