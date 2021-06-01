#!/bin/bash

###########################################################################################################################
# Starts configuration of POA. Installs required packages and dependencies , download scripts and configuration files
# and starts POA orchestration process
###########################################################################################################################

# Utility function to exit with message
unsuccessful_exit()
{
  echo "FATAL: Exiting script due to: $1, error code: $2" | tee -a $CONFIG_LOG_FILE_PATH;
  exit $2;
}

setup_dependencies()
{
	# Allow time for the network interfaces to stabilize
	sleep 60;

	################
	# Update modules
	################
	command_with_retry "sudo apt-get -y update" "update APT package handling utility.";
	# To avoid intermittent issues with package DB staying locked when next apt-get runs
	sleep 10;

	##################
	# Install packages
	##################
	command_with_retry "sudo apt-get -y install jq software-properties-common -y --allow-downgrades" "install git or jq.";

	# Install azure CLI
	AZ_REPO=$(lsb_release -cs)
	echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
	sudo tee /etc/apt/sources.list.d/azure-cli.list

	command_with_retry "sudo apt-key adv --keyserver packages.microsoft.com --recv-keys 52E16F86FEE04B979B07E28DB02C46DF417A0893" "Import packages.microsoft.com server keys failed.";
	curl -L https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add - || unsuccessful_exit "Failed to install a new key from packages.microsoft.com server" 4
	command_with_retry "sudo apt-get install apt-transport-https" "Failed to install apt-transport-https.";
	command_with_retry "sudo apt-get update && sudo apt-get install azure-cli" "Failed to install azure-cli.";

	# Configure azure-cli to not log telemetry due to issues with telemetry upload processes not finishing
	# https://docs.microsoft.com/en-us/cli/azure/azure-cli-configuration?view=azure-cli-latest#cli-configuration-values-and-environment-variables
	sudo sed -i -e "\$aAZURE_CORE_COLLECT_TELEMETRY=\"false\"" /etc/environment
}

install_docker() {

	echo "============== Installing docker engine ..."
	sudo apt-get remove docker docker-engine docker.io

	sudo apt-get install \
	apt-transport-https \
	ca-certificates \
	curl \
	software-properties-common

	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	sudo apt-get update
	apt-cache policy docker-ce
	sudo apt-get install -y docker-ce
	
	echo "=========== Finished installing docker engine."
}

# Retry Command`
# $1 : Command which run for  
# $2 : Error Message when the command($1) failed for $NOOFTRIES times
command_with_retry()
{
	success=0
	for LOOPCOUNT in `seq 1 $NOOFTRIES`; do
		eval $1
		EXIT_CODE=$?
		if [ $EXIT_CODE -ne 0 ]; then
			echo "Failed to $2 $LOOPCOUNT times with exit code $EXIT_CODE, retrying..." >> $CONFIG_LOG_FILE_PATH;
			# exponential back-off
			sleep $((5**$LOOPCOUNT));
			continue;
		else
			success=1
			break;
		fi
	done
	if [ $success -ne 1 ]; then
		unsuccessful_exit "Failed to $2 after $NOOFTRIES number of attempts." 5
	fi
}

# Acquires lease on container
acquire_lease_on_container()
{
	containerName=$1
    storageAccountName=$2
    accountKey=$3

    az storage container create --name $containerName --account-name $storageAccountName --account-key $accountKey --fail-on-exist;
    if [ $? -ne 0 ]; then
        echo "Attempt to create the lease container on storage account has failed." >> $CONFIG_LOG_FILE_PATH;
    else
		# TODO: acquire lease operation could fail. Make multiple attemps here
		id=$(az storage container lease acquire -c $containerName --lease-duration -1 --account-name $storageAccountName --account-key $accountKey --output tsv);
		if [ $? -eq 0 ]; then
			echo "Acquired lease on container." >> $CONFIG_LOG_FILE_PATH;
			echo "Lease ID:$id" >> $CONFIG_LOG_FILE_PATH;
			LEASE_ID=$id;
		fi
	fi
}

# Use MSI to get access token for authenticating to azure key vault 
get_access_token()
{
    auth_response=$(curl http://localhost:50342/oauth2/token -H 'Metadata:true' --data "resource=https://vault.azure.net");
    if [ $? -ne 0 ]; then unsuccessful_exit "Failed to authenticate with azure key vault." 6; fi
    accessToken=$(echo $auth_response | jq -r ".access_token")
    echo $accessToken;
}

# Use SPN to get access token for authentication to azure keyvault when MSI is not available
get_access_token_spn()
{
    # Required input
    fqdn=$1
    appid=$2
    key=$3
    tenantid=$4

    # Get audience
    audience=$(curl -s "https://management.$fqdn/metadata/endpoints?api-version=2015-01-01" | jq -r ".authentication.audiences[0]")

    # Define keyvault endpoint (replace management with vault in the url)
    resource="${audience/management/vault}" 

    # Get Token for Azure Stack Key Vault
    auth_response=$(curl -s --header "accept: application/json" --request POST "https://login.windows.net/$tenantid/oauth2/token" --data-urlencode "resource=$resource" --data-urlencode "client_id=$appid" --data-urlencode "grant_type=client_credentials" --data-urlencode "client_secret=$key");

    if [ $? -ne 0 ]; then unsuccessful_exit "Failed to authenticate with azure key vault." 51; fi
    accessToken=$(echo $auth_response | jq -r ".access_token")

    echo $accessToken;
}

download_docker_images() {
	echo "=========== Pulling docker image from azure container registry."
	command_with_retry "sudo docker login $DOCKER_REPOSITORY  -u $DOCKER_LOGIN -p $DOCKER_PASSWORD" "Unable to login to azure container registry.";
	command_with_retry "sudo docker pull $ORCHESTRATOR_DOCKER_IMAGE" "Failed to download docker image $ORCHESTRATOR_DOCKER_IMAGE.";
	echo "============ Finished pulling docker image from azure container registry."
}

# Attempts to run orchestration logic
orchestrate_poa()
{
	NumAttempt=$1
	isSuccessful=""

	for LOOPCOUNT in `seq 1 $NumAttempt`; do	
		# if [ "$ACCESS_TYPE" = "SPN" ]; then
		# 	ACCESS_TOKEN=$(get_access_token_spn "$ENDPOINTS_FQDN" "$SPN_APPID" "$SPN_KEY" "$AAD_TENANTID");
		# else
		# 	ACCESS_TOKEN=$(get_access_token);
		# fi
		ACCESS_TOKEN=""
		containerId=$(sudo docker run -d -v $DEPLOYMENT_LOG_PATH:$DEPLOYMENT_LOG_PATH -v $PARITY_DEV_PATH:$PARITY_DEV_PATH -v $CERTIFICATE_PATH:$CERTIFICATE_PATH -e NODE_ENV=production -e NodeCount=$NodeCount -e MODE=$MODE -e KEY_VAULT_BASE_URL=$KEY_VAULT_BASE_URL -e STORAGE_ACCOUNT=$STORAGE_ACCOUNT -e CONTAINER_NAME=$CONTAINER_NAME -e STORAGE_ACCOUNT_KEY=$STORAGE_ACCOUNT_KEY -e ETH_NETWORK_ID=$ETH_NETWORK_ID -e VALIDATOR_ADMIN_ACCOUNT=$VALIDATOR_ADMIN_ACCOUNT -e CONSORTIUM_DATA_URL=$CONSORTIUM_DATA_URL -e ACCESS_TOKEN=$ACCESS_TOKEN -e CONFIG_LOG_FILE_PATH=$CONFIG_LOG_FILE_PATH -e TRANSACTION_PERMISSION_CONTRACT="$TRANSACTION_PERMISSION_CONTRACT" -e AAD_TENANTID=$AAD_TENANTID -e SPN_KEY=$SPN_KEY -e SPN_APPID=$SPN_APPID -e RG_NAME=$RG_NAME -e KV_NAME=$KV_NAME -e ENDPOINTS_FQDN=$ENDPOINTS_FQDN -e IS_ADFS=$IS_ADFS --network host $ORCHESTRATOR_DOCKER_IMAGE);
		if [ $? -ne 0 ]; then
			unsuccessful_exit "Unable to run docker image $ORCHESTRATOR_DOCKER_IMAGE." 8;
			break;
		fi
        
		sudo docker wait $containerId
		exitCode=$(sudo docker inspect $containerId --format='{{.State.ExitCode}}');
		if [ $exitCode -ne 0 ]; then
			echo "Executing docker image $ORCHESTRATOR_DOCKER_IMAGE failed on try $LOOPCOUNT with exit code $exitCode." >> $CONFIG_LOG_FILE_PATH;
			sleep 2;
			continue;
		else
			echo "======== POA orchestration successful! ======== " >> $CONFIG_LOG_FILE_PATH;
			isSuccessful="SUCCESS";
			break;
		fi
	done

	if [ -z $isSuccessful ]; then
		unsuccessful_exit "Unable to orchestrate poa." ;
	fi
}

# Setup rc.local for service start on boot
setup_rc_local()
{
	echo "===== Started setup_rc_local =====";
    echo -e '#!/bin/bash' "\nsudo -u $AZUREUSER /bin/bash $HOMEDIR/configure-validator.sh \"$AZUREUSER\" \"$NodeCount\" \"$KEY_VAULT_BASE_URL\" \"$STORAGE_ACCOUNT\" \"$CONTAINER_NAME\" \"$STORAGE_ACCOUNT_KEY\" \"$VALIDATOR_ADMIN_ACCOUNT\" \"$NUM_BOOT_NODES\" \"$RPC_PORT\" \"$OMS_WORKSPACE_ID\" \"$OMS_PRIMARY_KEY\" \"$ADMIN_SITE_PORT\" \"$CONSORTIUM_MEMBER_ID\" \"$MODE\" \"$CONSORTIUM_DATA_URL\" \"$DOCKER_REPOSITORY\" \"$DOCKER_LOGIN\" \"$DOCKER_PASSWORD\" \"$DOCKER_IMAGE_ETHERADMIN\" \"$DOCKER_IMAGE_ETHSTAT\" \"$DOCKER_IMAGE_VALIDATOR\" \"$MUST_DEPLOY_GATEWAY\" \"$ACCESS_TYPE\" \"$ENDPOINTS_FQDN\" \"$SPN_APPID\" \"$SPN_KEY\" \"$AAD_TENANTID\" \"$RG_NAME\" \"$IS_ADFS\" >> $CONFIG_LOG_FILE_PATH 2>&1 & " | sudo tee /etc/rc.local 2>&1 1>/dev/null	
	if [ $? -ne 0 ]; then
		unsuccessful_exit "Failed to setup rc.local for restart on VM reboot." 3;
	fi
	echo "===== Completed setup_rc_local =====";
}

wget_with_retry()
{
	success=0
	for LOOPCOUNT in `seq 1 $NOOFTRIES`; do
		sudo -u $AZUREUSER /bin/bash -c "wget -N $1 --no-check-certificate";
		EXIT_CODE=$?
		if [ $EXIT_CODE -ne 0 ]; then
			echo "Failed to wget $1 $LOOPCOUNT times with exit code $EXIT_CODE, retrying..." >> $CONFIG_LOG_FILE_PATH;
			# exponential back-off
			sleep $((5**$LOOPCOUNT));
			continue;
		else
			success=1
			break;
		fi
	done
	if [ $success -ne 1 ]; then
		unsuccessful_exit "Failed to download $1 after $NOOFTRIES number of attempts." 8
	fi
}

is_poa_network_up() {
    if [ $(wc -l < $POA_NETWORK_UPFILE) -lt 1 ]; then echo 0; else echo 1; fi
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
    az cloud register -n AzureStackCloud --endpoint-resource-manager "https://management.$ENDPOINTS_FQDN" --suffix-storage-endpoint "$ENDPOINTS_FQDN" --suffix-keyvault-dns ".vault.$ENDPOINTS_FQDN"
    az cloud set -n AzureStackCloud
    az cloud update --profile 2018-03-01-hybrid
	az login --service-principal -u $SPN_APPID -p $SPN_KEY --tenant $AAD_TENANTID
}

####################################################################################
# Parameters : Validate that all arguments are supplied
####################################################################################
if [ $# -lt 31 ]; then unsuccessful_exit "Insufficient parameters supplied." 1; fi

AZUREUSER=$1
ARTIFACTS_URL_PREFIX=$2
NUM_BOOT_NODES=$3
NodeCount=$4
MODE=$5
OMS_WORKSPACE_ID=$6
OMS_PRIMARY_KEY=$7
KEY_VAULT_BASE_URL=$8
STORAGE_ACCOUNT=$9
STORAGE_ACCOUNT_KEY=${10}
RPC_PORT=${11}
ADMIN_SITE_PORT=${12}
CONSORTIUM_MEMBER_ID=${13}
ETH_NETWORK_ID=${14}
VALIDATOR_ADMIN_ACCOUNT=${15}
TRANSACTION_PERMISSION_CONTRACT=${16}
CONSORTIUM_DATA_URL=${17}
DOCKER_REPOSITORY=${18}
DOCKER_LOGIN=${19}
DOCKER_PASSWORD=${20}
DOCKER_IMAGE_POA_ORCHESTRATOR=${21}
DOCKER_IMAGE_ETHERADMIN=${22}
DOCKER_IMAGE_ETHSTAT=${23}
DOCKER_IMAGE_VALIDATOR=${24}
MUST_DEPLOY_GATEWAY=${25}

# Hybrid environment arguments
ACCESS_TYPE=${26}
SPN_APPID=${27}
SPN_KEY=${28}
ENDPOINTS_FQDN=${29}
AAD_TENANTID=${30}
RG_NAME=${31}
KV_NAME=${32}
IS_ADFS=${33}

# Echo out the parameters
echo "--- configure-poa.sh starting up ---"
echo "AZUREUSER = $AZUREUSER"
echo "ARTIFACTS_URL_PREFIX = $ARTIFACTS_URL_PREFIX"
echo "NUM_BOOT_NODES = $NUM_BOOT_NODES"
echo "NodeCount = $NodeCount"
echo "MODE=$MODE"
echo "OMS_WORKSPACE_ID=$OMS_WORKSPACE_ID"
echo "OMS_PRIMARY_KEY=$OMS_PRIMARY_KEY"
echo "KEY_VAULT_BASE_URL = $KEY_VAULT_BASE_URL"
echo "STORAGE_ACCOUNT = $STORAGE_ACCOUNT"
echo "STORAGE_ACCOUNT_KEY = $STORAGE_ACCOUNT_KEY"
echo "RPC_PORT = $RPC_PORT"
echo "ADMIN_SITE_PORT = $ADMIN_SITE_PORT"
echo "CONSORTIUM_MEMBER_ID = $CONSORTIUM_MEMBER_ID"
echo "ETH_NETWORK_ID = $ETH_NETWORK_ID"
echo "VALIDATOR_ADMIN_ACCOUNT = $VALIDATOR_ADMIN_ACCOUNT"
echo "TRANSACTION_PERMISSION_CONTRACT = $TRANSACTION_PERMISSION_CONTRACT"
echo "CONSORTIUM_DATA_URL=$CONSORTIUM_DATA_URL"
echo "DOCKER_REPOSITORY=$DOCKER_REPOSITORY"
echo "DOCKER_LOGIN=$DOCKER_LOGIN"
echo "DOCKER_PASSWORD=$DOCKER_PASSWORD"
echo "DOCKER_IMAGE_POA_ORCHESTRATOR = $DOCKER_IMAGE_POA_ORCHESTRATOR"
echo "DOCKER_IMAGE_ETHERADMIN=$DOCKER_IMAGE_ETHERADMIN"
echo "DOCKER_IMAGE_ETHSTAT=$DOCKER_IMAGE_ETHSTAT"
echo "DOCKER_IMAGE_VALIDATOR = $DOCKER_IMAGE_VALIDATOR"
echo "MUST_DEPLOY_GATEWAY=$MUST_DEPLOY_GATEWAY"
echo "ACCESS_TYPE=$ACCESS_TYPE"
echo "SPN_APPID=$SPN_APPID"
echo "SPN_KEY=$SPN_KEY"
echo "ENDPOINTS_FQDN=$ENDPOINTS_FQDN"
echo "AAD_TENANTID=$AAD_TENANTID"
echo "RG_NAME = $RG_NAME"
echo "KV_NAME = $KV_NAME"
echo "IS_ADFS = $IS_ADFS"

#####################################################################################
# Log Folder Locations
#####################################################################################
DEPLOYMENT_LOG_PATH="/var/log/deployment"
CERTIFICATE_PATH="/var/lib/waagent"
PARITY_LOG_PATH="/var/log/parity"
PARITY_RUN_PATH="/opt/parity"
ADMINSITE_LOG_PATH="/var/log/adminsite"
STATS_LOG_PATH="/var/log/stats"
CONFIG_LOG_FILE_PATH="$DEPLOYMENT_LOG_PATH/config.log";
PARITY_DEV_PATH="/tmp/parity"

#####################################################################################
# Create logging directories
#####################################################################################
sudo mkdir $PARITY_LOG_PATH
sudo chown :adm $PARITY_LOG_PATH
sudo chmod -R g+w $PARITY_LOG_PATH

sudo mkdir $PARITY_RUN_PATH
sudo chown :adm $PARITY_RUN_PATH
sudo chmod -R g+w $PARITY_RUN_PATH

sudo mkdir $PARITY_DEV_PATH
sudo chown :adm $PARITY_DEV_PATH
sudo chmod -R g+w $PARITY_DEV_PATH

sudo mkdir $DEPLOYMENT_LOG_PATH
sudo chown :adm $DEPLOYMENT_LOG_PATH
sudo chmod -R g+w $DEPLOYMENT_LOG_PATH

sudo mkdir $ADMINSITE_LOG_PATH
sudo chown :adm $ADMINSITE_LOG_PATH
sudo chmod -R g+w $ADMINSITE_LOG_PATH

sudo mkdir $STATS_LOG_PATH
sudo chown :adm $STATS_LOG_PATH
sudo chmod -R g+w $STATS_LOG_PATH


#####################################################################################
# Constants
#####################################################################################
CONTAINER_NAME="poa-config"
HOMEDIR="/home/$AZUREUSER";
LEASE_ID="";
NOOFTRIES=5
ETHERADMIN_HOME="$HOMEDIR/etheradmin";
ORCHESTRATOR_DOCKER_IMAGE="$DOCKER_REPOSITORY/$DOCKER_IMAGE_POA_ORCHESTRATOR"
SLEEP_INTERVAL_IN_SECS=2;
POA_NETWORK_UPFILE="$HOMEDIR/networkup.txt";

sudo -u $AZUREUSER touch $CONFIG_LOG_FILE_PATH

#####################################################################################
# Sanity check on parameters
if [ "$MODE" != "Leader" ] && [ "$MODE" != "Single" ] && [ "$MODE" != "Member" ]; then
	unsuccessful_exit "Invalid deployment mode." 2;
fi

###########################################
# Get the script for running as Azure user
###########################################
cd "$HOMEDIR";
wget_with_retry "${ARTIFACTS_URL_PREFIX}/scripts/poa-utility.sh";
wget_with_retry "${ARTIFACTS_URL_PREFIX}/scripts/configure-validator.sh";
wget_with_retry "${ARTIFACTS_URL_PREFIX}/scripts/run-validator.sh";

################################################
# Install packages and dependencies
################################################
cd "$HOMEDIR";
setup_dependencies

# Add user to docker group and install docker
sudo usermod -aG docker ${USER}
install_docker
################################################
# Copy required certificates for Azure CLI
################################################
setup_cli_certificates

################################################
# Configure Cloud Endpoints in Azure CLI
################################################
#configure_endpoints
sudo -u $AZUREUSER /bin/bash -c "mkdir -p $ETHERADMIN_HOME/public";
download_docker_images

#####################################################################################
# Acquire lease on container and run orchestrator logic
#####################################################################################
acquire_lease_on_container $CONTAINER_NAME $STORAGE_ACCOUNT  $STORAGE_ACCOUNT_KEY;
if [ ! -z $LEASE_ID ]; then
	orchestrate_poa $NOOFTRIES
fi

################################################################################################
# Run validator node.
################################################################################################
setup_rc_local
sudo -u $AZUREUSER /bin/bash /home/$AZUREUSER/configure-validator.sh "$AZUREUSER" "$NodeCount" "$KEY_VAULT_BASE_URL" "$STORAGE_ACCOUNT" "$CONTAINER_NAME" "$STORAGE_ACCOUNT_KEY" "$VALIDATOR_ADMIN_ACCOUNT" "$NUM_BOOT_NODES" "$RPC_PORT" "$OMS_WORKSPACE_ID" "$OMS_PRIMARY_KEY" "$ADMIN_SITE_PORT" "$CONSORTIUM_MEMBER_ID" "$MODE" "$CONSORTIUM_DATA_URL" "$DOCKER_REPOSITORY" "$DOCKER_LOGIN" "$DOCKER_PASSWORD" "$DOCKER_IMAGE_ETHERADMIN" "$DOCKER_IMAGE_ETHSTAT" "$DOCKER_IMAGE_VALIDATOR" "$MUST_DEPLOY_GATEWAY" "$ACCESS_TYPE" "$ENDPOINTS_FQDN" "$SPN_APPID" "$SPN_KEY" "$AAD_TENANTID" "$RG_NAME" "$IS_ADFS" >> $CONFIG_LOG_FILE_PATH 2>&1 &

############### Deployment Completed #########################
echo "Commands succeeded. Exiting";
exit 0;