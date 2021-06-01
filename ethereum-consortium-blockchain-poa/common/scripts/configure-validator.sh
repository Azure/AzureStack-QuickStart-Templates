#!/bin/bash

###################################################################################################################
# Downloads lease identity files , config files and docker images.
# Starts and run validator node.
# Establish network connection for a joining network.
# Starts etheradmin website and ethstat agents and make sure that they continue running.
###################################################################################################################

# Include utility script
. ~/poa-utility.sh

setup_docker() {

    # Remove existing containers (stopped and non stopped)
    sudo docker rm -f $(sudo docker ps -q)

  	echo "=========== Pulling docker image from azure container registry."

	command_with_retry "sudo docker login $DOCKER_REPOSITORY  -u $DOCKER_LOGIN -p $DOCKER_PASSWORD" "Unable to login to azure container registry.";
	command_with_retry "sudo docker pull $ETHSTAT_DOCKER_IMAGE" "Failed to download docker image $ETHSTAT_DOCKER_IMAGE.";
	command_with_retry "sudo docker pull $ETHERADMIN_DOCKER_IMAGE" "Failed to download docker image $ETHERADMIN_DOCKER_IMAGE.";
	
    echo "============ Finished pulling docker image from azure container registry."
}

setup_cli_certificates()
{
    if [ "$ACCESS_TYPE" = "SPN" ]; then
		sudo cp /var/lib/waagent/Certificates.pem /usr/local/share/ca-certificates/azsCertificate.crt
		sudo update-ca-certificates
		export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
		sudo sed -i -e "\$aREQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt" /etc/environment
	fi
    
	if [[ ! -z "$IS_ADFS" ]]; then
		#if [[ $SPN_KEY != *"servicePrincipalCertificate.pem"* ]]; then
		spCertName="$SPN_KEY.crt"
		spCertKey="$SPN_KEY.prv"
		sudo cp /var/lib/waagent/$spCertName /home/
		sudo cp /var/lib/waagent/$spCertKey /home/
		sudo cat /home/$spCertName /home/$spCertKey > /home/servicePrincipalCertificate.pem
		sudo chmod 644 /home/servicePrincipalCertificate.pem
		#SPN_KEY=/home/servicePrincipalCertificate.pem
		az cloud register -n AzureStackCloud --endpoint-resource-manager "https://management.$ENDPOINTS_FQDN" --suffix-storage-endpoint "$ENDPOINTS_FQDN" --suffix-keyvault-dns ".vault.$ENDPOINTS_FQDN"
		az cloud set -n AzureStackCloud
		az cloud update --profile 2018-03-01-hybrid
		az login --service-principal -u $SPN_APPID -p /home/servicePrincipalCertificate.pem --tenant $AAD_TENANTID
		#fi
	else
		az cloud register -n AzureStackCloud --endpoint-resource-manager "https://management.$ENDPOINTS_FQDN" --suffix-storage-endpoint "$ENDPOINTS_FQDN" --suffix-keyvault-dns ".vault.$ENDPOINTS_FQDN"
		az cloud set -n AzureStackCloud
		az cloud update --profile 2018-03-01-hybrid
		az login --service-principal -u $SPN_APPID -p $SPN_KEY --tenant $AAD_TENANTID
	fi
}

configure_endpoints()
{
    if [ "$ACCESS_TYPE" = "SPN" ]; then
		sudo cp /var/lib/waagent/Certificates.pem /usr/local/share/ca-certificates/azsCertificate.crt
		sudo update-ca-certificates
		export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
		sudo sed -i -e "\$aREQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt" /etc/environment
	fi
    
    az cloud register -n AzureStackCloud --endpoint-resource-manager "https://management.$ENDPOINTS_FQDN" --suffix-storage-endpoint "$ENDPOINTS_FQDN" --suffix-keyvault-dns ".vault.$ENDPOINTS_FQDN"
    az cloud set -n AzureStackCloud
    az cloud update --profile 2018-03-01-hybrid
	az login --service-principal -u $SPN_APPID -p $SPN_KEY --tenant $AAD_TENANTID
}

alreadyLoggedEthStatWarning=0;

start_ethstat() {
    if [ -z "$OMS_WORKSPACE_ID" -a "$ACCESS_TYPE" != "SPN" ]; 
    then
        if [ $alreadyLoggedEthStatWarning -eq 0 ];
        then
            echo "===== Not starting blockchain stat collector agent due to OMS_WORKSPACE_ID not being provided =====";
            alreadyLoggedEthStatWarning=1;
        fi
    else
        echo "===== Starting blockchain stat collector agent =====";
        cid=$(sudo docker ps | grep '-ethstat' | awk '{print $1}');
        if [ ! -z $cid ]; then
            sudo docker kill $cid
        fi
        
        containerId=$(sudo docker run -d -v $STATS_LOG_PATH:$STATS_LOG_PATH -e NODE_ENV=production -e ipaddr=$IPADDR -e rpcPort=$RPC_PORT -e sharedKey=$OMS_PRIMARY_KEY -e customerId=$OMS_WORKSPACE_ID  -e logFile=$ETHSTAT_LOG_FILE --network host $ETHSTAT_DOCKER_IMAGE);
        if [ $? -ne 0 ]; then
		    unsuccessful_exit "Unable to run docker image $ETHSTAT_DOCKER_IMAGE." 32;
	    fi

        isRunning=$(docker_wait_for_running_state 5 2 $containerId);
        if [ $isRunning -ne 1  ]; then unsuccessful_exit "Failed to start container from image $ETHSTAT_DOCKER_IMAGE." 33; fi

        echo "===== Started blockchain stat collector agent =====";
    fi
}

start_admin_website(){    
    echo "===== Starting etheradmin website =====";
    cid=$(sudo docker ps | grep '-etheradmin' | awk '{print $1}');
    if [ ! -z $cid ]; then
       sudo docker kill $cid
    fi

    #if [ "$ACCESS_TYPE" = "SPN" ]; then
    #    STORAGE_DNS_SUFFIX=$ENDPOINTS_FQDN
    #else
    #    STORAGE_DNS_SUFFIX="core.windows.net"
    #fi
    
    STORAGE_DNS_SUFFIX=$ENDPOINTS_FQDN
    STORAGE_API_VERSION="2017-04-17"

    containerId=$(sudo docker run -d -v "/var/lib/waagent/":"/var/lib/waagent/" -v $ADMINSITE_LOG_PATH:$ADMINSITE_LOG_PATH -v $PARITY_VOLUME:$PARITY_VOLUME -v $ETHERADMIN_HOME/public:/usr/src/app/share -e NODE_ENV=production -e listenPort="$ADMIN_SITE_PORT" -e consortiumId="$CONSORTIUM_MEMBER_ID" -e azureStorageAccount="$STORAGE_ACCOUNT" -e azureStorageAccessKey="$STORAGE_ACCOUNT_KEY" -e containerName="$CONTAINER_NAME" -e identityBlobPrefix="$BLOB_NAME_PREFIX" -e ethRpcPort="$RPC_PORT" -e validatorListBlobName="$VALIDATOR_LIST_BLOB_NAME" -e paritySpecBlobName="$PARITY_SPEC_BLOB_NAME" -e valSetContractBlobName="$VALSET_CONTRACT_BLOB_NAME" -e adminContractBlobName="$ADMIN_CONTRACT_BLOB_NAME" -e adminContractABIBlobName="$ADMIN_CONTRACT_ABI_BLOB_NAME" -e adminSiteLogFile="$ADMINSITE_LOG_FILE" -e storageDnsSuffix="$STORAGE_DNS_SUFFIX" -e storageApiVersion="$STORAGE_API_VERSION" -e userCert="$CERT_FILE" -e AZURE_STORAGE_DNS_SUFFIX="$STORAGE_DNS_SUFFIX" -e NODE_EXTRA_CA_CERTS="$CERT_FILE" --network host $ETHERADMIN_DOCKER_IMAGE);
    if [ $? -ne 0 ]; then
        unsuccessful_exit "Unable to run docker image $ETHADMIN_DOCKER_IMAGE." 32;
    fi

    echo "Etheradmin docker ContainerId: " $containerId;
    isRunning=$(docker_wait_for_running_state 5 2 $containerId);
    if [ $isRunning -ne 1 ]; then unsuccessful_exit "Failed to start container from image $ETHADMIN_DOCKER_IMAGE." 33; fi

    echo "===== Started etheradmin website =====";
}

# Starts a validator node. 
run_validator()
{
    sudo -u $AZUREUSER /bin/bash /home/$AZUREUSER/run-validator.sh "$AZUREUSER" "$NODE_COUNT" "$STORAGE_ACCOUNT" "$CONTAINER_NAME" "$STORAGE_ACCOUNT_KEY" "$ADMINID" "$NUM_BOOT_NODES" "$RPC_PORT" "$MODE" "$VALIDATOR_DOCKER_IMAGE" "$CONSORTIUM_DATA_URL" "$MUST_DEPLOY_GATEWAY" "$ACCESS_TYPE" "$ENDPOINTS_FQDN" "$SPN_APPID" "$SPN_KEY" "$AAD_TENANTID" "$RG_NAME" "$IS_ADFS" >> $CONFIG_LOG_FILE_PATH 2>&1 & 
}

join_leaders_network() {

    NETWORK_INFO=$(curl "$CONSORTIUM_DATA_URL/networkinfo")

    REMOTE_NODES_COUNT=$(echo $NETWORK_INFO | jq '.bootnodes | length')
    if [ $REMOTE_NODES_COUNT -eq 0 ]; then 
         unsuccessful_exit "Unable to get boot nodes from leader network."  34
    fi

    if [[ $MUST_DEPLOY_GATEWAY == "True" ]]; then
        firstEnodeUrl=$(echo $NETWORK_INFO | jq '.bootnodes[0]')
        IP_TO_PING=$(echo ${firstEnodeUrl#*@} | cut -d: -f1)
        echo "IP to ping before starting parity:${IP_TO_PING}"

        while [ ${#IP_TO_PING} -gt 0 ]
        do
            ping -c 1 $IP_TO_PING > /dev/null

            if [ $? -eq 0 ]
            then
                echo "Network connection established"
                break
            fi

            sleep 60
        done
    fi
}

is_poa_network_up() {
    if [ $(wc -l < $POA_NETWORK_UPFILE) -lt 1 ]; then echo 0; else echo 1; fi
}

is_etheradmin_up(){
    id=$(sudo docker ps | grep '-etheradmin' | awk '{print $1}');
    if [ ! -z $id ]; then echo 1; else echo 0; fi
}

is_ethstat_up(){
    id=$(sudo docker ps | grep '-ethstat' | awk '{print $1}');
    if [ ! -z "$id" -a "$ACCESS_TYPE" = "SPN" ]; then echo 1; else echo 0; fi
}

####################################################################################
# Parameters : Validate that all arguments are supplied
####################################################################################
if [ $# -lt 26 ]; then unsuccessful_exit "Insufficient parameters supplied." 35; fi

AZUREUSER=$1;
NODE_COUNT=$2;
KEY_VAULT_BASE_URL=$3;
STORAGE_ACCOUNT=$4;
CONTAINER_NAME=$5;
STORAGE_ACCOUNT_KEY=$6;
ADMINID=$7;
NUM_BOOT_NODES=$8;
RPC_PORT=$9;
OMS_WORKSPACE_ID=${10};
OMS_PRIMARY_KEY=${11};
ADMIN_SITE_PORT=${12};
CONSORTIUM_MEMBER_ID=${13};
MODE=${14}
CONSORTIUM_DATA_URL=${15}
DOCKER_REPOSITORY=${16}
DOCKER_LOGIN=${17}
DOCKER_PASSWORD=${18}
DOCKER_IMAGE_ETHERADMIN=${19}
DOCKER_IMAGE_ETHSTAT=${20}
DOCKER_IMAGE_VALIDATOR=${21}
MUST_DEPLOY_GATEWAY=${22}

# Hybrid environment arguments
ACCESS_TYPE=${23}
ENDPOINTS_FQDN=${24}
SPN_APPID=${25}
SPN_KEY=${26}
AAD_TENANTID=${27}
RG_NAME=${28}
IS_ADFS=${29}

# Echo out the parameters
echo "--- configure-validator.sh starting up ---"
echo "AZUREUSER = $AZUREUSER"
echo "NODE_COUNT = $NODE_COUNT"
echo "KEY_VAULT_BASE_URL = $KEY_VAULT_BASE_URL"
echo "STORAGE_ACCOUNT = $STORAGE_ACCOUNT"
echo "CONTAINER_NAME = $CONTAINER_NAME"
echo "STORAGE_ACCOUNT_KEY=$STORAGE_ACCOUNT_KEY"
echo "ADMINID=$ADMINID"
echo "NUM_BOOT_NODES=$NUM_BOOT_NODES"
echo "RPC_PORT=$RPC_PORT"
echo "OMS_WORKSPACE_ID=$OMS_WORKSPACE_ID"
echo "OMS_PRIMARY_KEY=$OMS_PRIMARY_KEY"
echo "ADMIN_SITE_PORT=$ADMIN_SITE_PORT"
echo "CONSORTIUM_MEMBER_ID=$CONSORTIUM_MEMBER_ID"
echo "MODE=$MODE"
echo "CONSORTIUM_DATA_URL=$CONSORTIUM_DATA_URL"
echo "DOCKER_REPOSITORY=$DOCKER_REPOSITORY"
echo "DOCKER_LOGIN=$DOCKER_LOGIN"
echo "DOCKER_PASSWORD=$DOCKER_PASSWORD"
echo "DOCKER_IMAGE_ETHERADMIN=$DOCKER_IMAGE_ETHERADMIN"
echo "DOCKER_IMAGE_ETHSTAT=$DOCKER_IMAGE_ETHSTAT"
echo "MUST_DEPLOY_GATEWAY=$MUST_DEPLOY_GATEWAY"
echo "ACCESS_TYPE=$ACCESS_TYPE"
echo "ENDPOINTS_FQDN=$ENDPOINTS_FQDN"
echo "SPN_APPID=$SPN_APPID"
echo "SPN_KEY=$SPN_KEY"
echo "AAD_TENANTID=$AAD_TENANTID"
echo "RG_NAME=$RG_NAME"
echo "IS_ADFS=$IS_ADFS"

#####################################################################################
# Log Folder Locations
#####################################################################################
PARITY_LOG_PATH="/var/log/parity"
ADMINSITE_LOG_PATH="/var/log/adminsite"
STATS_LOG_PATH="/var/log/stats"
DEPLOYMENT_LOG_PATH="/var/log/deployment"
CERT_FILE="/var/lib/waagent/Certificates.pem"
CONFIG_LOG_FILE_PATH="$DEPLOYMENT_LOG_PATH/config.log";
ADMINSITE_LOG_FILE="$ADMINSITE_LOG_PATH/etheradmin.log"
ETHSTAT_LOG_FILE="$STATS_LOG_PATH/ethstat.log"

#####################################################################################
# Constants
#####################################################################################
HOMEDIR="/home/$AZUREUSER";
ETHERADMIN_HOME="$HOMEDIR/etheradmin";
CONFIGDIR="$HOMEDIR/config";
SLEEP_INTERVAL_IN_SECS=10;
BOOT_NODES_FILE="$HOMEDIR/bootnodes.txt";
IPADDR=$(ifconfig eth0 | sed -En 's/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
PARITY_IPC_PATH="/opt/parity/jsonrpc.ipc";
PARITY_VOLUME="/opt/parity";
BLOB_NAME_PREFIX="passphrase-";
REMOTE_NODES_COUNT=0
ETHSTAT_DOCKER_IMAGE="$DOCKER_REPOSITORY/$DOCKER_IMAGE_ETHSTAT"
ETHERADMIN_DOCKER_IMAGE="$DOCKER_REPOSITORY/$DOCKER_IMAGE_ETHERADMIN"
VALIDATOR_DOCKER_IMAGE="$DOCKER_REPOSITORY/$DOCKER_IMAGE_VALIDATOR"
NETWORK_INFO=""
POA_NETWORK_UPFILE="$HOMEDIR/networkup.txt";

################################################
# Copy required certificates for Azure CLI
################################################
setup_cli_certificates

################################################
# Configure Cloud Endpoints in Azure CLI
################################################
#configure_endpoints

##########################################################################################################
#	Wait for orchestrator to finish
##########################################################################################################
echo "Waiting for lease records and config files to be created by orchestrator ...";

# Expect the passphrase-X.json files, spec.json, ValidatorSet.sol, AdminValidatorSet.sol, and AdminValidatorSet.sol.abi files
fileCount=$(($NODE_COUNT + 4)) 

found=$(wait_for_orchestrator $CONTAINER_NAME $STORAGE_ACCOUNT $STORAGE_ACCOUNT_KEY $fileCount);
if [ "$found" == "FALSE" ]; then
    unsuccessful_exit "Unable to start validator node. The expected number of lease records and config files were not found in blob container." 36
fi

# setup docker
setup_docker

##################################################################################
# Download spec.json and passphrase blob records to local folder
##################################################################################
download_config "$STORAGE_ACCOUNT" "$CONTAINER_NAME" "$STORAGE_ACCOUNT_KEY" "$CONFIGDIR";

####################################################################
# Establish network connection to leader for member deployment
####################################################################
if [ "$MODE" == "Member" ]; then
    join_leaders_network
fi

# Run validator node
run_validator

##################################################################################################
# Keep ethstat agent and etheradmin website running.
##################################################################################################
while sleep $SLEEP_INTERVAL_IN_SECS; do

    if [ $(is_poa_network_up) -eq 1 ]; then 
        if [ $(is_etheradmin_up) -eq 0 ]; then start_admin_website; fi;
        if [ $(is_ethstat_up) -eq 0 ]; then start_ethstat; fi;
    fi

done

exit 1;