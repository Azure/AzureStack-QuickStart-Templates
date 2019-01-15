#!/bin/bash

##########################################################################################################################
# Starts a validator node and make sure that it continuous running by renewing lease identity or acquires a new identity. 
##########################################################################################################################

# ( for debug only)
# set -x 

# Include utility script
. ~/poa-utility.sh

setup_cli_certificates()
{
	if [ "$ACCESS_TYPE" = "SPN" ]; then
		sudo cp /var/lib/waagent/Certificates.pem /usr/local/share/ca-certificates/azsCertificate.crt
		sudo update-ca-certificates
		export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
		sudo sed -i -e "\$aREQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt" /etc/environment
	fi
}

configure_endpoints()
{
    az cloud register -n AzureStackCloud --endpoint-resource-manager "https://management.$ENDPOINTS_FQDN" --suffix-storage-endpoint "$ENDPOINTS_FQDN" --suffix-keyvault-dns ".vault.$ENDPOINTS_FQDN"
    az cloud set -n AzureStackCloud
    az cloud update --profile 2018-03-01-hybrid
	az login --service-principal -u $SPN_APPID -p $SPN_KEY --tenant $AAD_TENANTID
}

# Iterate through lease records and attempt to acquire a new lease
acquire_lease()
{
    ################################################
    # Copy required certificates for Azure CLI
    ################################################
    setup_cli_certificates

    ################################################
    # Configure Cloud Endpoints in Azure CLI
    ################################################
    configure_endpoints

    leaseId="";

    # TODO: List blobs and iterate through instead of iterating through downloaded files
    for i in `seq 0 $(($NodeCount - 1))`; do
        blobname="passphrase-$i.json";
        leaseId=$(az storage blob lease acquire --blob-name $blobname --container-name $CONTAINER_NAME --lease-duration $LEASE_DURATION_IN_SECS --account-name $STORAGE_ACCOUNT --account-key $STORAGE_ACCOUNT_KEY --output tsv);

        if [ $? -ne 0 ]; then
            echo "Attempt to acquire a lease has failed.";
        else
            PASSPHRASE_FILE_NAME=$blobname;
            LEASE_ID=$leaseId;
            start_node $blobname
            break;
        fi
    done
}

# Renew an existing lease
renew_lease()
{
    ################################################
    # Copy required certificates for Azure CLI
    ################################################
    setup_cli_certificates

    ################################################
    # Configure Cloud Endpoints in Azure CLI
    ################################################
    configure_endpoints

    az storage blob lease renew --blob-name $PASSPHRASE_FILE_NAME --container-name $CONTAINER_NAME --lease-id $LEASE_ID --account-name $STORAGE_ACCOUNT --account-key $STORAGE_ACCOUNT_KEY > /dev/null;
    if [ $? -ne 0 ]; then
        echo "Attempt to renew lease with lease id $LEASE_ID failed."
        LEASE_ID="";
        PASSPHRASE_FILE_NAME="";
        stop_node
    fi
}

# Starts a validator node. 
start_node()
{
    blobname=$1;
    # Get passphrase from KeyVault and store it in password file
    PASSPHRASE_URI=$(cat "$CONFIGDIR/$blobname" | jq -r ".passphraseUri");
    if [ -z $PASSPHRASE_URI ]; then
        unsuccessful_exit "Unable to start validator node. Passphrase url should not be empty." 40
    fi

    keyVaultUrl="$PASSPHRASE_URI?api-version=2016-10-01";
    
    if [ "$ACCESS_TYPE" = "SPN" ]; then
        accessToken=$(get_access_token_spn "$ENDPOINTS_FQDN" "$SPN_APPID" "$SPN_KEY" "$AAD_TENANTID");
    else
        accessToken=$(get_access_token);
    fi

    keyVaultResponse=$(curl $keyVaultUrl -H "Content-Type: application/json" -H "Authorization: Bearer $accessToken");
    echo "Get KeyVault secret response: $keyVaultResponse";
    passphrase=$(echo $keyVaultResponse | jq -r ".value");
    if [ -z $passphrase ]; then
        unsuccessful_exit "Unable to start validator node. Passphrase should not be empty." 41
    fi

    sudo docker run -d -v $PARITY_DATA_PATH:$PARITY_DATA_PATH -v $HOMEDIR:$HOMEDIR -v $DEPLOYMENT_LOG_PATH:$DEPLOYMENT_LOG_PATH -v $PARITY_LOG_PATH:$PARITY_LOG_PATH -e AZUREUSER=$AZUREUSER -e STORAGE_ACCOUNT=$STORAGE_ACCOUNT -e CONTAINER_NAME=$CONTAINER_NAME -e STORAGE_ACCOUNT_KEY=$STORAGE_ACCOUNT_KEY -e ADMINID=$ADMINID -e NUM_BOOT_NODES=$NUM_BOOT_NODES -e RPC_PORT=$RPC_PORT -e PASSPHRASE=$passphrase -e PASSPHRASE_FILE_NAME=$blobname -e PASSPHRASE_URI=$PASSPHRASE_URI -e MODE=$MODE -e LEASE_ID=$LEASE_ID -e CONSORTIUM_DATA_URL=$CONSORTIUM_DATA_URL -e MUST_DEPLOY_GATEWAY=$MUST_DEPLOY_GATEWAY -e CONFIG_LOG_FILE_PATH=$CONFIG_LOG_FILE_PATH -e PARITY_LOG_FILE_PATH=$PARITY_LOG_FILE_PATH --network host --restart on-failure $DOCKER_IMAGE_VALIDATOR 
    if [ $? -ne 0 ]; then
        unsuccessful_exit "Unable to run docker image $VALIDATOR_DOCKER_IMAGE." 42;
    fi
}

# Reset variables and files
reset_state() {
    rm -f $BOOT_NODES_FILE; 
    touch $BOOT_NODES_FILE;
    rm -f $POA_NETWORK_UPFILE; 
    touch $POA_NETWORK_UPFILE;
    touch $PARITY_IPC_PATH
    PASSPHRASE_URI="";
}

# Stop validator node.
stop_node()
{

    # Stop validator process
    cid=$(sudo docker ps | grep 'poa-validator' | awk '{print $1}');
    if [ ! -z $cid ]; then
        sudo docker kill $cid
    fi

	echo "Stopped validator node.";
    reset_state;
}

####################################################################################
# Parameters : Validate that all arguments are supplied
####################################################################################
if [ $# -lt 11 ]; then unsuccessful_exit "Insufficient parameters supplied." 43; fi

AZUREUSER=$1;
NodeCount=$2;
STORAGE_ACCOUNT=$3;
CONTAINER_NAME=$4;
STORAGE_ACCOUNT_KEY=$5;
ADMINID=$6;
NUM_BOOT_NODES=$7;
RPC_PORT=$8;
MODE=$9
DOCKER_IMAGE_VALIDATOR=${10}
CONSORTIUM_DATA_URL=${11}
MUST_DEPLOY_GATEWAY=${12}

# Hybrid environment arguments
ACCESS_TYPE=${26}
ENDPOINTS_FQDN=${27}
SPN_APPID=${28}
SPN_KEY=${29}
AAD_TENANTID=${30}

# Echo out the parameters
echo "--- configure-validator.sh starting up ---"
echo "AZUREUSER=$AZUREUSER"
echo "NodeCount=$NodeCount"
echo "STORAGE_ACCOUNT=$STORAGE_ACCOUNT"
echo "CONTAINER_NAME=$CONTAINER_NAME"
echo "STORAGE_ACCOUNT_KEY=$STORAGE_ACCOUNT_KEY"
echo "ADMINID=$ADMINID"
echo "NUM_BOOT_NODES=$NUM_BOOT_NODES"
echo "RPC_PORT=$RPC_PORT"
echo "MODE=$MODE"
echo "DOCKER_IMAGE_VALIDATOR=$DOCKER_IMAGE_VALIDATOR"
echo "CONSORTIUM_DATA_URL=$CONSORTIUM_DATA_URL"
echo "MUST_DEPLOY_GATEWAY=$MUST_DEPLOY_GATEWAY"
echo "ACCESS_TYPE=$ACCESS_TYPE"
echo "ENDPOINTS_FQDN=$ENDPOINTS_FQDN"
echo "SPN_APPID=$SPN_APPID"
echo "SPN_KEY=$SPN_KEY"
echo "AAD_TENANTID=$AAD_TENANTID"

#####################################################################################
# Log Folder Locations
#####################################################################################
DEPLOYMENT_LOG_PATH="/var/log/deployment"
CONFIG_LOG_FILE_PATH="$DEPLOYMENT_LOG_PATH/config.log";

#####################################################################################
# Constants
#####################################################################################
HOMEDIR="/home/$AZUREUSER";
CONFIGDIR="$HOMEDIR/config";
PASSPHRASE_FILE_NAME="";
LEASE_ID="";
RENEW_INTERVAL_IN_SECS=10;
LEASE_DURATION_IN_SECS=30;
BOOT_NODES_FILE="$HOMEDIR/bootnodes.txt";
PASSPHRASE_URI="";
PARITY_VOLUME="/opt/parity";
POA_NETWORK_UPFILE="$HOMEDIR/networkup.txt";
PARITY_DATA_PATH="/opt/parity"
PARITY_LOG_FILE_PATH="/var/log/parity/parity.log"
PARITY_IPC_PATH="/opt/parity/jsonrpc.ipc"
PARITY_LOG_PATH="/var/log/parity"

reset_state;

##################################################################################################
# Keep the process running. Every [RENEW_INTERVAL_IN_SECS] seconds attempt to renew or acquire a lease
##################################################################################################
while sleep $RENEW_INTERVAL_IN_SECS; do

    if [ -z $LEASE_ID ]; then
        acquire_lease
    else
        renew_lease
    fi

done

echo "Failed to run validator node. Exiting."

exit 1;