# Mesos cluster with Marathon/Chronos frameworks
This Microsoft Azure stack template create Mesos cluster with Marathon/Chronos frameworks

## Deployed resources

Once your cluster has been created you will have a resource group containing 3 parts:

1. a set of 1,3,5 masters nodes.  Each master's SSH can be accessed via the public dns address at ports 2200..2204

2. a set of agents node.  The agent VMs must be accessed through the master, or jumpbox

3. a windows jumpbox

The following image is an example of a cluster with 1 jumpbox, 3 masters, and 3 agents:

![Image of Mesos cluster on azure Stack](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/develop/mesos-windows-jumpbox/images/mesos.png)

You can see the following parts:

1. **Mesos on port 5050** - Mesos is the distributed systems kernel that abstracts cpu, memory and other resources, and offers these to services named "frameworks" for scheduling of workloads.
2. **Marathon on port 8080** - Marathon is a scheduler for Mesos that is equivalent to init on a single linux machine: it schedules long running tasks for the whole cluster.
3. **Chronos on port 4400** - Chronos is a scheduler for Mesos that is equivalent to cron on a single linux machine: it schedules periodic tasks for the whole cluster.
4. **Docker on port 2375** - The Docker engine runs containerized workloads and each Master and Agent run the Docker engine.  Mesos runs Docker workloads, and examples on how to do this are provided in the Marathon and Chronos walkthrough sections of this readme.

All VMs are on the same private subnet, 10.0.0.0/18, and fully accessible to each other.

## Prerequisites

Follow the below links to create/download an Ubuntu 14.04 LTS Image and upload the same to Azure Stack's Platform Image Repository(PIR)
1. https://azure.microsoft.com/en-us/documentation/articles/azure-stack-linux/
2. https://azure.microsoft.com/en-us/documentation/articles/azure-stack-add-image-pir/
	Note: please use the default values for linuxPublisher,linuxOffer,linuxSku,linuxVersion found in azuredeploy.json while creating the manifest.json in PIR

## Deployment steps
=> Deploy to azurestack, using custom deployment in azurestack portal.
=> or use DeployMesos.ps1 to deploy to azurestack via powershell.

## Usage

This walk through is based the wonderful digital ocean tutorial: https://www.digitalocean.com/community/tutorials/how-to-configure-a-production-ready-mesosphere-cluster-on-ubuntu-14-04

1. Get your endpoints to cluster
 1. browse to https://portal.azurestack.local

 2. then click browse all, followed by "resource groups", and choose your resource group

 ![Image of resource groups in portal](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/develop/mesos-windows-jumpbox/images/portal-resourcegroups.png)

 3. then expand your resources, and copy the dns names of your jumpbox (if chosen), and your NAT public ip addresses.

 ![Image of public ip addresses in portal](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/develop/mesos-windows-jumpbox/images/portal-publicipaddresses.png)

2. Connect to your windows jumpbox - remote desktop to the windows jumpbox

3. browse to the Mesos UI on the windows jumpbox - open browser , the master URL is set as default page

4. Browse Mesos:
 1. scroll down the page and notice your resources of CPU and memory.  These are your agents

 ![Image of Mesos cluster on azure](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/develop/mesos-windows-jumpbox/images/mesos-webui.png)

 2. On top of page, click frameworks and notice your Marathon and Chronos frameworks

 ![Image of Mesos cluster frameworks on azure](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/develop/mesos-windows-jumpbox/images/mesos-frameworks.png)

 3. On top of page, click agents and you can see your agents.  On windows jumpbox you can also drill down into the slave and see its logs.

 ![Image of Mesos agents on azure](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/develop/mesos-windows-jumpbox/images/mesos-agents.png)

5. browse and explore Marathon UI http://<MasterhostName>:8080 (or if using tunnel http://localhost:8080 )

6. start a long running job in Marathon
 1. click "+New App"
 2. type "myfirstapp" for the id
 3. type "/bin/bash -c "for i in {1..5}; do echo MyFirstApp $i; sleep 1; done" for the command
 4. scroll to bottom and click create

 ![Image of Marathon new app dialog](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/develop/mesos-windows-jumpbox/images/marathon-newapp.png)

7. you will notice the new app change state from not running to running

 ![Image of the new application status](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/develop/mesos-windows-jumpbox/images/marathon-newapp-status.png)

8. browse back to Mesos http://<MasterHostname>:5050.  You will notice the running tasks and the completed tasks.  Click on the host of the completed tasks and also look at the sandbox.

 ![Image of Mesos completed tasks](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/develop/mesos-windows-jumpbox/images/mesos-completed-tasks.png)

9. All nodes are running docker, so to run a docker app browse back to Marathon UI, and create an application to run "sudo docker run hello-world".  Once running browse back to Mesos in a similar fashion to the above instructions to see that it has run:

 ![Image of setting up docker application in Marathon](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/develop/mesos-windows-jumpbox/images/marathon-docker.png)

## Chronos Walkthrough

1. from the jumpbox browse to http://<masterhostname>:4400/, and verify you see the Chronos Web UI:

 ![Image of Chronos UI](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/develop/mesos-windows-jumpbox/images/chronos-ui.png)

2. Click Add and fill in the following details:
 1. Name - "MyFirstApp"
 2. Command - "echo "my first app on Chronos""
 3. Owner, and Owner Name - you can put random information Here
 4. Schedule - Set to P"T1M" in order to run this every minute

 ![Image of adding a new scheduled operation in Chronos](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/develop/mesos-windows-jumpbox/images/chronos.png)

3. Click Create

4. Watch the task run, and then browse back to the Mesos UI and observe the output in the completed task.

5. All nodes are running docker, so to run a docker app browse back to Chronos UI, and create an application to run "sudo docker run hello-world".  Once running browse back to Mesos in a similar fashion to the above instructions to verify that it has run:

 ![Image of setting up docker application in Marathon](https://raw.githubusercontent.com/Azure/AzureStack-QuickStart-Templates/develop/mesos-windows-jumpbox/images/chronos-docker.png)

 
# Sample Workloads

Try the following workloads to test your new mesos cluster.  Run these on Marathon using the examples above

1. **Folding@Home** - [docker run rgardler/fah](https://hub.docker.com/r/rgardler/fah/) - Folding@Home is searching for a cure for Cancer, Alzheimers, Parkinsons and other such diseases. Donate some compute time to this fantastic effort.

# Questions
**Q.** Why is there a jumpbox for the mesos Cluster?

**A.** The jumpbox is used for easy troubleshooting on the private subnet.  The Mesos Web UI requires access to all machines.  Also the web UI.  You could also consider using OpenVPN to access the private subnet.

**Q.** My cluster just completed but Mesos is not up.

**A.** After your template finishes, your cluster is still running installation.  You can run "tail -f /var/log/azure/cluster-bootstrap.log" to verify the status has completed.

## Notes

 * This version of Mesos is a non-HA(no Loadbalancer or Availabilitysets) with master, Agent node deployment.
 * Refer https://help.ubuntu.com/community/SSH/OpenSSH/Keys#Generating_RSA_Keys for generating sshkeys for ubuntu
 * the installation log for the masters, and agents are in /var/log/azure/cluster-bootstrap.log
 * event though the VMs finish quickly Mesos can take 5-15 minutes to install, check /var/log/azure/cluster-bootstrap.log for the completion status. 
