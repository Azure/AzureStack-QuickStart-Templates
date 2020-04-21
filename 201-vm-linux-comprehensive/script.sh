set -e

echo "Starting test configuration for VM comprehensive."
date

echo "Running as:"
whoami

sleep 20

echo "Update the system."
sudo apt-get update -y

# Prerequiste on Ubuntu 16.04 for AzureCLI
echo "Update prerequiste for AzureCLI."
sudo apt-get install -y libssl-dev libffi-dev python-dev build-essential -y

echo "Install Python 3.5"
sudo apt-get install python3.5 -y

echo "Install Python PIP."
sudo apt-get install python-pip -y

echo "Upgrading Python PIP."
pip install --upgrade pip

echo "Install AzureCLI."
curl -sL https://aka.ms/InstallAzureCLI | sudo bash

# Run simple command to test availablity AzureCLI
echo "Running: az --version"
az --version

echo "Completed test configuration for VM comprehensive."
