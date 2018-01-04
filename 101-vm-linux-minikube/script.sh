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


echo "downloading minikube binary"
sudo curl -Lo minikube $MINIKUBELINK && sudo chmod +x minikube && sudo mv minikube /usr/local/bin/

echo "downloading kubectl binary"
sudo curl -Lo kubectl $KUBECTLLINK && sudo chmod +x kubectl &&  sudo mv kubectl /usr/local/bin/

echo "update the system"
sudo apt-get -y update

echo "add docker repo key"
sudo curl -fsSL $DOCKERLINK/gpg | sudo apt-key add -

echo "add docker repo" 
sudo add-apt-repository "deb [arch=amd64] $DOCKERLINK $(lsb_release -cs) stable"

echo "re-update the system"
sudo apt-get -y update

echo "install docker"
sudo apt-get -y install docker-ce

echo "Install xfce4"
sudo apt-get -y update

echo "Install xfce4"
sudo apt-get -y install xfce4

echo "Install xrdp"
sudo apt-get -y install xrdp

echo "Configure xsession"
sudo echo xfce4-session >~/.xsession

echo "Restart xrdp"
sudo service xrdp restart

echo "Install Firefox"
sudo apt-get -y install firefox

echo "Minikube Deployment Done"
