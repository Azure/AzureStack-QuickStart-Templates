# Deploy a Linux VM with Public IP and Minikube

This template deploys a single Linux VM (Ubuntu 16.04 by default), latest stable release of Docker-CE, latest stable release of minikube and kubectl on it. It also opens up ssh port so that user can connect to the VM using the public ip and play with minikube. Minikube needs a virtualization driver such as virtualbox in order to run. However, this template is designed to force Minikube to run the virtualization natively using docker on the host machine. This approach helps in lowering the VM CPU Cores and Memory requirements. Hence, when running Minikube, please start with VM-Driver=None option set. 

sudo minikube start --vm-driver=none

