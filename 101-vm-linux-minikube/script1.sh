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

echo "start minikube"
sudo minikube start --vm-driver=none
sleep 20

sudo kubectl cluster-info | grep 'running' &> /dev/null
if [ $? == 0 ]; then
   echo "Minikube started successfully"
fi

echo "Minikube Deployment Done"
