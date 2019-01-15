#!/bin/bash

#################################################################################################################
# Configure an engine signer and run parity. It also runs the node discovery mechanisms to identify boot nodes.
#################################################################################################################

# Utility function to exit with message
unsuccessful_exit()
{
  echo "FATAL: Exiting script due to: $1. Exit code: $2";
  exit $2;
}

# Upload a blob to azure storage
upload_blob_with_retry()
{
    file=$1;
    blobName=$2;
    storageAccountName=$3;
    storageContainerName=$4;
    accountKey=$5;
    leaseId=$6;
    notries=$7;
	
    success=0
	for loopcount in $(seq 1 $notries); do

        if [ -z $leaseId ]; then
            az storage blob upload -c $storageContainerName -n $blobName -f $file --account-name $storageAccountName --account-key $accountKey;
        else
            az storage blob upload -c $storageContainerName -n $blobName -f $file --lease-id $leaseId --account-name $storageAccountName --account-key $accountKey;
        fi

		if [ $? -ne 0 ]; then
			continue;
		else
			success=1
			break;
		fi
	done
    return $success;
}

# Invoke Parity JSON RPC API via IPC call
invoke_parity_jsonipc_method() {
    local method=$1;
    local paramList=$2;
    local methodId=$3;
    local ipcFilePath=$PARITY_IPC_PATH;
    local ipcCommand='{"jsonrpc":"2.0","method":"'$method'","params":'$paramList',"id":'$methodId'}';
    printf $ipcCommand | nc -U -w 1 -q 1 $ipcFilePath;
}

# Shutdown parity process
shutdown_parity()
{
    kill -9 $(ps aux | grep '[p]arity -' | awk '{print $2}');
    # Give time for the process to stop
    sleep 5;
}


# Returns address given a passphrase.
get_address_from_phrase()
{
    local passphrase=$1;
    local paritylog=$2;
    local maxRetrys=5;
    local currentRetries=0;

    # Start parity in the background
    parity --config none_authority.toml >> $paritylog 2>&1 &
    if [ $? -ne 0 ]; then unsuccessful_exit "Unable to generate address. Parity failed to start." 51; fi

    # Wait for IPC file to open
    sleep $RPC_PORT_WAIT_IN_SECS;
    
    sudo chown :adm $PARITY_IPC_PATH;
    sudo chmod -R g+w $PARITY_IPC_PATH;

    local account=$(invoke_parity_jsonipc_method 'parity_newAccountFromPhrase' '["'$passphrase'","'$passphrase'"]' 0);
    while [ $currentRetries -lt $maxRetrys ] && [ -z "$account" ]; do    
        let currentRetries=currentRetries+1;
        sleep $((5**$currentRetries));
        local account=$(invoke_parity_jsonipc_method 'parity_newAccountFromPhrase' '["'$passphrase'","'$passphrase'"]' 0);
    done
     
    if [ -z "$account" ]; then unsuccessful_exit "Unable to generate address. Maximum number of retries exceeded." 57; fi

    # Parse the result to return just the account address
    local address=$(echo $account | jq -r ".result");

    shutdown_parity # shutdown parity on completion

    echo $address;
}

# Appends enode url of the current node to azure storage blob
publish_enode_url() {

    enodeUrl=$(invoke_parity_jsonipc_method "parity_enode" "[]" 0 | jq -r ".result");

    if [[ $enodeUrl =~ ^enode ]]; then
        hostname=$(hostname);
        echo "{\"passphraseUri\": \"${PASSPHRASE_URI}\", \"enodeUrl\": \"${enodeUrl}\", \"hostname\": \"$hostname\"}" > nodeid.json;
        success=$(upload_blob_with_retry "nodeid.json" $PASSPHRASE_FILE_NAME $STORAGE_ACCOUNT $CONTAINER_NAME $STORAGE_ACCOUNT_KEY $LEASE_ID $NOOFTRIES);
	    if [ $? -ne 1 ]; then
            unsuccessful_exit "Unable to publish enode url to azure storage blob after $NOOFTRIES attempts." 52
        fi
    else
        unsuccessful_exit "Parity is not configured properly. The enode url is not valid." 53
    fi
}

add_enode_to_boot_nodes_file() {
    local enodeUrl=$1;
     # Only write to the file when a new boot node is found
    if [ ! -z $(grep "$enodeUrl" "$BOOT_NODES_FILE") ]; then 
        echo "enode already exists in boot node file: $enode";
    else
        echo $enodeUrl >> $BOOT_NODES_FILE;
    fi
}

# Add discovered node to parity and append the enode url to bootnodes file
add_parity_reserved_peer() {
    filename=$1;
    az storage blob download -c $CONTAINER_NAME -n "$filename"  -f "$CONFIGDIR/$filename" --account-name $STORAGE_ACCOUNT --account-key $STORAGE_ACCOUNT_KEY;
    if [ $? -ne 0 ]; then
        echo "Failed to download lease blob $filename." # no need to retry here since we attempt until NUM_BOOT_NODES has been discovered
    else
        enodeUrl=$(cat "$CONFIGDIR/$filename" | jq -r ".enodeUrl");
        echo "Discovered node with enode url: $enodeUrl";
        if [[ $enodeUrl =~ ^enode ]]; then
            invoke_parity_jsonipc_method "parity_addReservedPeer" '["'$enodeUrl'"]' 0
            if [ $? -ne 0 ]; then
                unsuccessful_exit "Failed to add bootnode to parity." 54
            fi

            add_enode_to_boot_nodes_file $enodeUrl;
        else
            echo "enode url value invalid."
        fi
    fi
}


# Discover other nodes in the network and connect to them with parity_addReservedPeer api
discover_nodes() {

    # Get list of active validator node lease blobs
    leaseBlobs=$(az storage blob list --query '[?properties.lease.state==`leased`].name' -c $CONTAINER_NAME --account-name $STORAGE_ACCOUNT --account-key $STORAGE_ACCOUNT_KEY );
    echo $leaseBlobs > activenodes.json;

    # Download lease blob and retrieve the enode url ( if available ) for each active node
    jq -c '.[]' activenodes.json | while read file; do
        leaseBlobName=$(echo $file | tr -d '"');
        if [ "$PASSPHRASE_FILE_NAME" != "$leaseBlobName"  ]; then  # skip if lease is for current node
            add_parity_reserved_peer $leaseBlobName;
        fi
    done
}

discover_more_nodes() {
    if [ $(wc -l < $BOOT_NODES_FILE) -lt $NUM_BOOT_NODES ]; then echo 1; else echo 0; fi
}

set_ExtraData() {
    # Update the miner ExtraData field    
    echo "Setting parity ExtraData field to $1"
    invoke_parity_jsonipc_method "parity_setExtraData" '["'$1'"]' 1
}

add_remote_peers() {
    cd $HOMEDIR
    networkInfo=$(curl "$CONSORTIUM_DATA_URL/networkinfo")
    echo $networkInfo | jq -c '.bootnodes[]' | while IFS='' read url;do
        enodeUrl=$(echo $url | jq -r '.')
        if [ ! -z $enodeUrl ]; then
            invoke_parity_jsonipc_method "parity_addReservedPeer" '["'$enodeUrl'"]' 0
            echo "Added remote $enodeUrl to parity."

            add_enode_to_boot_nodes_file $enodeUrl;
        fi
    done
}

# configures and run parity.
run_parity()
{

    echo "Passphrase: $PASSPHRASE";
    echo $PASSPHRASE > $PASSWORD_FILE;

    # Inject engine signer address and admin id to node.toml
    address=$(get_address_from_phrase $PASSPHRASE $PARITY_LOG_FILE_PATH);
    if [ -z $address ]; then
        unsuccessful_exit "Unable to generate validator address from passphrase." 55
    else
        echo "Engine signer: $address";
    fi

    sed s/#ENGINE_SIGNER/$address/ $HOMEDIR/node.toml > $HOMEDIR/node1.toml;
    sed s/#ETH_RPC_PORT/$RPC_PORT/ $HOMEDIR/node1.toml > $CONFIGDIR/node.toml;

    if [[ $MUST_DEPLOY_GATEWAY == "False" ]]; then
        # Look up the assigned public ip for this VMSS instance using Azure "Instance Metadata Service"
        local publicIp=$(curl -s -H Metadata:true http://169.254.169.254/metadata/instance?api-version=2017-04-02 | jq -r .network.interface[0].ipv4.ipAddress[0].publicIpAddress);
        echo "Public IP: " ${publicIp};
        sed -i s/#EXTERNALIP#/$publicIp/ $CONFIGDIR/node.toml;
    else
        # Delete the external IP line
        sed -i /#EXTERNALIP#/d $CONFIGDIR/node.toml;
    fi

    # Cleanup temp files
    rm -f node1.toml;
    
    echo "Starting parity on validator node..."
    parity --config $CONFIGDIR/node.toml --force-ui -lclient,sync,discovery,engine,poa,shutdown,chain,executive=debug >> $PARITY_LOG_FILE_PATH 2>&1 &
    
    # Allow time for the Parity client to start
    sleep $RPC_PORT_WAIT_IN_SECS; # Wait for RPC port to open
    
    sudo chown :adm $PARITY_IPC_PATH;
    sudo chmod -R g+w $PARITY_IPC_PATH;

    # Run tasks
    publish_enode_url;
    set_ExtraData $ADMINID

    if [ "$MODE" == "Member" ]; then  add_remote_peers; fi
}

####################################################################################
# Parameters : Validate that all arguments are supplied
####################################################################################
if [ $# -lt 15 ]; then unsuccessful_exit "Insufficient parameters supplied." 56; fi

AZUREUSER=$1
STORAGE_ACCOUNT=$2;
CONTAINER_NAME=$3;
STORAGE_ACCOUNT_KEY=$4;
ADMINID=$5;
NUM_BOOT_NODES=$6;
RPC_PORT=$7;
PASSPHRASE=$8
PASSPHRASE_FILE_NAME=$9
PASSPHRASE_URI=${10}
MODE=${11}
LEASE_ID=${12}
CONSORTIUM_DATA_URL=${13}
MUST_DEPLOY_GATEWAY=${14}
PARITY_LOG_FILE_PATH=${15}

# Constants
NOOFTRIES=3;
HOMEDIR="/home/$AZUREUSER";
CONFIGDIR="$HOMEDIR/config";
SLEEP_INTERVAL_IN_SECS=2;
BOOT_NODES_FILE="$HOMEDIR/bootnodes.txt";
RPC_PORT_WAIT_IN_SECS=15;
POA_NETWORK_UPFILE="$HOMEDIR/networkup.txt";
PASSWORD_FILE="$HOMEDIR/node.pwd";
PARITY_IPC_PATH="/opt/parity/jsonrpc.ipc"

# start validator node
run_parity

# discover nodes until enough boot nodes have been found
while sleep $SLEEP_INTERVAL_IN_SECS; do

    if [ $(discover_more_nodes) -eq 1 ]; then 
        discover_nodes; 
    else    
        break;
    fi;

done

echo "poa network started" > $POA_NETWORK_UPFILE 
echo "Successfully started validator node."