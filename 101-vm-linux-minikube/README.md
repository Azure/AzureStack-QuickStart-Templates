# Deploy a Linux VM with Public IP and Minikube

This template deploys a single Linux VM (Ubuntu 16.04 by default) and installs following components,

* Docker-CE from https://download.docker.com/linux/ubuntu, 
* Kubectl from https://storage.googleapis.com/kubernetes-release/release/v1.8.0/bin/linux/amd64/kubectl
* Minikube from https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
* xFCE4 and xRDP

It starts the xFCE4 server so that users can RDP to linux box using its public IP. Users can also ssh to the linux box using the same public ip.


Minikube needs a virtualization driver such as virtualbox in order to run. However, this template is designed to force Minikube to run the virtualization natively using docker on the host machine. This approach helps in lowering the VM CPU Cores and Memory requirements. 


Hence, when running Minikube, please start with VM-Driver=None option set. 

To Start using Minikube, connect to the linux box using its public IP via RDP or SSH and issue following command

sudo minikube start --vm-driver=none

