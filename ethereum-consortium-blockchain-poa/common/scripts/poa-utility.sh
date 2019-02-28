#!/bin/bash

####################################################################################
# Constants
####################################################################################
VALIDATOR_LIST_BLOB_NAME="AddressList.json"
PARITY_SPEC_BLOB_NAME="spec.json"
VALSET_CONTRACT_BLOB_NAME="SimpleValidatorSet.sol"
ADMIN_CONTRACT_BLOB_NAME="AdminValidatorSet.sol"
ADMIN_CONTRACT_ABI_BLOB_NAME="AdminValidatorSet.sol.abi"

####################################################################################
# Helper and utility functions
####################################################################################

# Utility function to exit with message
unsuccessful_exit()
{
  echo "FATAL: Exiting script due to: $1. Exit code: $2";
  exit $2;
}

get_ip_address()
{
	rgName=$1
    publicIp=$(az network public-ip list -g $rgName -o json | jq '.[0]' | jq -r ".ipAddress")

	echo $publicIp;
}

# Use MSI to get access token for authenticating to azure key vault 
get_access_token()
{
    auth_response=$(curl http://localhost:50342/oauth2/token -H 'Metadata:true' --data "resource=https://vault.azure.net");
    if [ $? -ne 0 ]; then unsuccessful_exit "Failed to authenticate with azure key vault." 51; fi
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

# Wait until all lease records and config files are created by the orchestrator
wait_for_orchestrator()
{
	containerName=$1
    storageAccountName=$2;
    accountKey=$3
	expectedBlobCount=$4;
	found="FALSE";
	
    # TODO : should not wait indefinately for orchestrator. Detrmine appropriate running time for orchestrator.
	while sleep 10; do		
		blobCount=$(az storage blob list --container-name $containerName --account-name $storageAccountName --account-key $accountKey | jq '. | length');
		if [ $blobCount -ge $expectedBlobCount ]; then
			found="TRUE";
			break
        else
            continue    
		fi		
	done

	echo $found;
}

# Download lease records 
download_config()
{
    storageAccountName=$1
    storageContainerName=$2
    accountKey=$3
    destination=$4;
    
    mkdir -p $destination;
    az storage blob download-batch --source $storageContainerName --destination $destination --account-name $storageAccountName --account-key $accountKey; 
}

wget_with_retry()
{
    file=$1
    numAttempt=$2
    outputFile=$3

	success=0
	for i in `seq 1 $numAttempt`; do
		if [ -z $outputFile ]; then
            wget -N $1
        else
            wget -N $1 -O $2
        fi
		exit_code=$?
		if [ $exit_code -ne 0 ]; then
			echo "Failed to wget $file $i times with exit code $exit_code, retrying..." 
			# exponential back-off
			sleep $((5**$i));
			continue;
		else
			success=1
			break;
		fi
	done
	if [ $success -ne 1 ]; then
		unsuccessful_exit "Unable to download file $file after $numAttempt number of attempts." 52
	fi
}

# Wait until docker state changes to "Running"
docker_wait_for_running_state() {

    NoAttempts=$1
    sleepInSec=$2
    containerId=$3

    success=0;
    for loopCount in `seq 1 $NoAttempts`; do
		isRunning=$(sudo docker inspect -f {{.State.Running}} $containerId)
		if [ $isRunning != "true"  ]; then
			sleep $sleepInSec;
			continue;
		else
			success=1;
			break;
		fi
	done
    echo $success;
}

# Retry Command
# $1 : Command which run for  
# $2 : Error Message when the command($1) failed for $NOOFTRIES times
command_with_retry()
{
	success=0
	numAttempt=3;
	for loopCount in `seq 1 $numAttempt`; do
		eval $1
		exit_code=$?
		if [ $exit_code -ne 0 ]; then
			echo "Failed to $2 $loopCount times with exit code $exit_code, retrying..." ;
			# exponential back-off
			sleep $((5**$loopCount));
			continue;
		else
			success=1
			break;
		fi
	done
	if [ $success -ne 1 ]; then
		unsuccessful_exit "Failed to $2 after $numAttempt number of attempts." 53
	fi
}










