# Hadoop Cluster

## ARM Templates

### Dependencies

This template requires Ubuntu 16.04LTS and Custom Script 2.0 for Linux to function.

### hadoop_cluster.json

This ARM template will setup your Hadoop cluster along with a jump box used to transfer data.

### jumpbox_node.json

This ARM template will deploy the jumpbox which is used to manage and copy date to your Hadoop cluster.

### master_node.json

This ARM template will deploy the Hadoop master nodes with each given a public IP address.

### worker_node.json

This ARM template will deploy the Hadoop worker nodes.

## Virtual Machine Extensions

### Hadoop Cluster Setup

This script will download and install hadoop on each machine.  This includes

* Install Hadoop pre-requisites
* Download and extract Hadoop
* Create user accounts

### Jumpbox Setup

Hadoop Node Setup Script

* Log into each machine and
  * Configure Hadoop for that node type
  * Copy SSH keys to other nodes
  * Add Hadoop to startup
  * Restart VMs to finalize installation
