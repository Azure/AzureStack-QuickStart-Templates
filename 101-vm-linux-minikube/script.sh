set -e

echo "Starting Minikube Deployment..."
date

echo "Running as:"
whoami

sleep 20

echo "downloading minikube binary"
sudo curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && sudo chmod +x minikube && sudo mv minikube /usr/local/bin/

echo "downloading kubectl binary"
sudo curl -Lo kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && sudo chmod +x kubectl &&  sudo mv kubectl /usr/local/bin/

echo "update the system"
sudo apt-get -y update

echo "add docker repo key"
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

echo "add docker repo" 
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

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
