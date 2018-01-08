set -e

echo "Starting Minikube Deployment..."
date

echo "Running as:"
whoami

sleep 20
#############
# Parameters
#############
MINIKUBELINK=${1}
KUBECTLLINK=${2}
DOCKERLINK=${3}

#############
# Retry Function
#############
retrycmd_if_failure() { for i in 1 2 3 4 5; do $@; [ $? -eq 0  ] && break || sleep 5; done ; }

echo "downloading minikube binary"
retrycmd_if_failure sudo curl -Lo minikube $MINIKUBELINK && sudo chmod +x minikube && sudo mv minikube /usr/local/bin/

echo "downloading kubectl binary"
retrycmd_if_failure sudo curl -Lo kubectl $KUBECTLLINK && sudo chmod +x kubectl &&  sudo mv kubectl /usr/local/bin/

echo "update the system"
retrycmd_if_failure sudo apt-get -y update

echo "add docker repo key"
retrycmd_if_failure sudo curl -fsSL $DOCKERLINK/gpg | sudo apt-key add -

echo "add docker repo" 
sudo add-apt-repository "deb [arch=amd64] $DOCKERLINK $(lsb_release -cs) stable"

echo "re-update the system"
retrycmd_if_failure sudo apt-get -y update

echo "install docker"
retrycmd_if_failure sudo apt-get -y install docker-ce

echo "Install xfce4"
retrycmd_if_failure sudo apt-get -y update

echo "Install xfce4"
retrycmd_if_failure sudo apt-get -y install xfce4

echo "Install xrdp"
retrycmd_if_failure sudo apt-get -y install xrdp

echo "Configure xsession"
retrycmd_if_failure sudo echo xfce4-session >~/.xsession

echo "Restart xrdp"
retrycmd_if_failure sudo service xrdp restart

echo "Install Firefox"
retrycmd_if_failure sudo apt-get -y install firefox

echo "Minikube Deployment Done"
