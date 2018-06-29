# install azure CLI with the following command line on Ubuntu 16+
# sudo apt-get update
# sudo apt-get install -y libssl-dev libffi-dev python-dev build-essential
# curl -L https://aka.ms/InstallAzureCli | bash
	
MyGatewayResourceId=$1
OtherGatewayResourceId=$2
ConnectionName=$3
SharedKey=$4

# MyGatewayResourceId tells me what subscription I am in, what ResourceGroup and the VNetGatewayName
IFS='/'
read -r -a arr <<< "$MyGatewayResourceId"
MySubscriptionId=`echo "${arr[2]}"`
MyResourceGroup=`echo "${arr[4]}"`
IFS=''

az account set --subscription $MySubscriptionId
az network vpn-connection create --name $ConnectionName --resource-group $MyResourceGroup --vnet-gateway1 $MyGatewayResourceId --shared-key $SharedKey --vnet-gateway2 $OtherGatewayResourceId --enable-bgp
