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

# Stores secret in key vault.
set_secret_in_keyvault()
{
    vaultBaseUrl=$1
    secretName=$2
    secretValue=$3
    accessToken=$4
    aadTenantId=$5
    spnKey=$6
    spnAppId=$7
    rgName=$8
    kvName=$9

    az login --service-principal -u $spnAppId -p $spnKey --tenant $aadTenantId
    az keyvault create -n $kvName -g $rgName

    if [ -z $spnKey]; then 
        url="$vaultBaseUrl/secrets/$secretName?api-version=2016-10-01"
        data="{\"value\": \"${secretValue}\"}"
        
        setSecretResponse=$(curl -X PUT $url -d "$data" -H "Content-Type: application/json" -H "Authorization: Bearer $accessToken");    
        secretUri=$(echo $setSecretResponse | jq -r ".id");
    else 
        setSecretResponse=$(az keyvault secret set -n $secretName --vault-name $kvName --value $secretValue);
        secretUri=$(echo $setSecretResponse | jq -r ".id");
    fi
    echo $secretUri;
}

generate_upload_prefund_account() {
	prefund_account_passphrase=$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 32);
	if [ $? -ne 0  ] || [ -z $prefund_account_passphrase ]; then
		unsuccessful_exit "Unable to generate prefund passphrase." 60
	fi
	echo $prefund_account_passphrase > $PREFUND_PASSPHRASE_FILE;

	PREFUND_ACCOUNT_ADDRESS=$(curl --data '{"jsonrpc":"2.0","method":"parity_newAccountFromPhrase","params":["'$prefund_account_passphrase'", "'$prefund_account_passphrase'"],"id":0}' -H "Content-Type: application/json" -X POST localhost:8545 | jq -r ".result");
	if [ $? -ne 0  ] || [ -z $PREFUND_ACCOUNT_ADDRESS ]; then
		unsuccessful_exit "Unable to generate prefund account address." 61
	fi
	echo "Prefund address: $PREFUND_ACCOUNT_ADDRESS"

	success=$(upload_blob_with_retry $PREFUND_PASSPHRASE_FILE $PREFUND_PASSPHRASE_FILE $STORAGE_ACCOUNT $CONTAINER_NAME $STORAGE_ACCOUNT_KEY "" $NOTRIES);
	if [ $? -ne 1 ]; then
		unsuccessful_exit "Unable to upload prefund passphrase file to azure storage blob after $NOTRIES attempts." 62
	fi
}

# Generates the spec.json file
generate_poa_spec()
{
    validatorAddressList=$1
    storageAccountName=$2
    storageContainerName=$3
    accountKey=$4
    ethNetworkId=$5
    nodeCount=$6
    initialValidatorAdminAddress=$7
    transactionPermissionContract=$8


    echo "Node Count: $nodeCount"
    # Inject validator list in contract file and compile the smart contract    
    sed 's/validatorCapacity = 13;/validatorCapacity = '$nodeCount';/g' AdminValidatorSet.sol > AdminValidatorSet.sol.bak
	sed 's/0x0000000000000000000000000000000000000000/'"$initialValidatorAdminAddress"'/g' SimpleValidatorSet.sol > SimpleValidatorSet.pre0.sol
	sed 's/0x1111111111111111111111111111111111111111/'"$validatorAddressList"'/g' SimpleValidatorSet.pre0.sol > SimpleValidatorSet.pre1.sol

    mv SimpleValidatorSet.pre1.sol $VALSET_CONTRACT_BLOB_NAME;
    mv AdminValidatorSet.sol.bak $ADMIN_CONTRACT_BLOB_NAME;

	byteCode=$(nodejs compile-contract.js "$ADMIN_CONTRACT_ABI_BLOB_NAME")
	if [ -z $byteCode ]; then
		unsuccessful_exit "Contract bytecode should not be empty or null." 63;
	fi

    # Convert Network ID to Hex
    eth_network_id_hex='0x'$(printf "%x\n" $ethNetworkId)
    
    # Remove transaction permissioning contract setting if contract bytecode is not available
    if [ -z $transactionPermissionContract ]; then 
        sed -i '/transactionPermissionContract/d' spec.json
        sed -i '/0x0000000000000000000000000000000000000005/d' spec.json
    fi

    # Inject bytecode to spec.json file
    sed s/#CONTRACT_BYTE_CODE/$byteCode/ spec.json > spec1.json;
    sed s/#ETH_NETWORK_ID/$eth_network_id_hex/ spec1.json > spec2.json;
    sed s/#TRANSACTION_PERMISSION_CONTRACT/$transactionPermissionContract/ spec2.json > $PARITY_SPEC_BLOB_NAME;

    # Upload spec.js to azure storage
    uploadAttempts=3
    upload_blob_with_retry "$PARITY_SPEC_BLOB_NAME" "$PARITY_SPEC_BLOB_NAME" "$storageAccountName" "$storageContainerName" "$accountKey" "" "$uploadAttempts";
    if [ $? -ne 1 ]; then
	    unsuccessful_exit "Unable to upload $PARITY_SPEC_BLOB_NAME file to azure storage blob after $uploadAttempts attempts." 64
    fi
    # Upload SimpleValidatorSet.sol to azure storage
    upload_blob_with_retry "$VALSET_CONTRACT_BLOB_NAME" "$VALSET_CONTRACT_BLOB_NAME" "$storageAccountName" "$storageContainerName" "$accountKey" "" "$uploadAttempts";
    if [ $? -ne 1 ]; then
	    unsuccessful_exit "Unable to upload $VALSET_CONTRACT_BLOB_NAME file to azure storage blob after $uploadAttempts attempts." 64
    fi
    # Upload AdminValidatorSet.sol to azure storage
    upload_blob_with_retry "$ADMIN_CONTRACT_BLOB_NAME" "$ADMIN_CONTRACT_BLOB_NAME" "$storageAccountName" "$storageContainerName" "$accountKey" "" "$uploadAttempts";
    if [ $? -ne 1 ]; then
	    unsuccessful_exit "Unable to upload $$ADMIN_CONTRACT_BLOB_NAME file to azure storage blob after $uploadAttempts attempts." 64
    fi
    # Upload AdminValidatorSet.sol.abi to azure storage
    upload_blob_with_retry "$ADMIN_CONTRACT_ABI_BLOB_NAME" "$ADMIN_CONTRACT_ABI_BLOB_NAME" "$storageAccountName" "$storageContainerName" "$accountKey" "" "$uploadAttempts";
    if [ $? -ne 1 ]; then
	    unsuccessful_exit "Unable to upload $ADMIN_CONTRACT_ABI_BLOB_NAME file to azure storage blob after $uploadAttempts attempts." 64
    fi

    # Cleanup files
    rm spec.json
    rm spec1.json;
    rm spec2.json;	
}

# Upload passphrase uri record as json file to a blob container
upload_uri_to_blob()
{
    storageAccountName=$1
    storageContainerName=$2
    accountKey=$3
    uriFile=$4
    passphraseUri=$5
    
    # Create json file and put the passphrase uri in the file
    json='{"passphraseUri": "'$passphraseUri'"}'
	echo $json > $uriFile

    # Upload json file to blob and remove the file from working directory 
    uploadAttempts=3
    upload_blob_with_retry "$uriFile" "$uriFile" "$storageAccountName" "$storageContainerName" "$accountKey" "" "$uploadAttempts";
    if [ $? -ne 1 ]; then
	    unsuccessful_exit "Unable to upload passphrase URI file - $uriFile - to azure storage blob after $uploadAttempts attempts." 65
    fi

    rm -rf $uriFile
}

# This allows member nodes to use the same information as leader
# and act as a leader in the future
host_network_info_from_leader()
{
    consortium_data_url=$1
    network_info_file_name="networkinfo.json"
    curl_get_with_retry "$consortium_data_url/networkinfo" > $network_info_file_name

    nodejs process-network-info.js "$network_info_file_name" "$PARITY_SPEC_BLOB_NAME" "$VALSET_CONTRACT_BLOB_NAME" "$ADMIN_CONTRACT_BLOB_NAME" "$ADMIN_CONTRACT_ABI_BLOB_NAME"
    
    # Upload spec.json to azure storage
    upload_blob_with_retry "$PARITY_SPEC_BLOB_NAME" "$PARITY_SPEC_BLOB_NAME" "$storageAccountName" "$storageContainerName" "$accountKey" "" "$uploadAttempts";
    if [ $? -ne 1 ]; then
	    unsuccessful_exit "Unable to upload $PARITY_SPEC_BLOB_NAME file to azure storage blob after $uploadAttempts attempts." 64
    fi

    # Upload SimpleValidatorSet.sol to azure storage
    upload_blob_with_retry "$VALSET_CONTRACT_BLOB_NAME" "$VALSET_CONTRACT_BLOB_NAME" "$storageAccountName" "$storageContainerName" "$accountKey" "" "$uploadAttempts";
    if [ $? -ne 1 ]; then
	    unsuccessful_exit "Unable to upload $VALSET_CONTRACT_BLOB_NAME file to azure storage blob after $uploadAttempts attempts." 64
    fi

    # Upload AdminValidatorSet.sol to azure storage
    upload_blob_with_retry "$ADMIN_CONTRACT_BLOB_NAME" "$ADMIN_CONTRACT_BLOB_NAME" "$storageAccountName" "$storageContainerName" "$accountKey" "" "$uploadAttempts";
    if [ $? -ne 1 ]; then
	    unsuccessful_exit "Unable to upload $ADMIN_CONTRACT_BLOB_NAME file to azure storage blob after $uploadAttempts attempts." 64
    fi
    
    # Upload AdminValidatorSet.sol.abi to azure storage
    upload_blob_with_retry "$ADMIN_CONTRACT_ABI_BLOB_NAME" "$ADMIN_CONTRACT_ABI_BLOB_NAME" "$storageAccountName" "$storageContainerName" "$accountKey" "" "$uploadAttempts";
    if [ $? -ne 1 ]; then
	    unsuccessful_exit "Unable to upload $ADMIN_CONTRACT_ABI_BLOB_NAME file to azure storage blob after $uploadAttempts attempts." 64
    fi
}

# Makes address list available for download from Azure Storage
make_address_list_available_for_download()
{
    addressList=$1
    storageAccountName=$2
    storageContainerName=$3
    accountKey=$4

    # Address list will be stored in JSON in the format { addresses: [a1,a2,a3]}
    addressFileName=$VALIDATOR_LIST_BLOB_NAME
    addressListJson='{"addresses": ['$addressList']}'
	echo $addressListJson > $addressFileName
	
    # Upload address list to azure storage
    uploadAttempts=3
    upload_blob_with_retry "$addressFileName" "$addressFileName" "$storageAccountName" "$storageContainerName" "$accountKey" "" "$uploadAttempts";
    if [ $? -ne 1 ]; then
	    unsuccessful_exit "Unable to upload address list file to azure storage blob after $uploadAttempts attempts." 66
    fi
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
            echo "az storage blob upload -c $storageContainerName -n $blobName -f $file --account-name $storageAccountName --account-key $accountKey"
            az storage blob upload -c $stovi 
            rageContainerName -n $blobName -f $file --account-name $storageAccountName --account-key $accountKey;
        else
            echo ""
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
		unsuccessful_exit "Unable to download file $file after $numAttempt number of attempts." 67
	fi
}

curl_get_with_retry(){

    url=$1
    numAttempt=$2

	success=0
	for i in `seq 1 $numAttempt`; do

        output=$(curl $1)
		exit_code=$?
		if [ $exit_code -ne 0 ]; then
			# exponential back-off
			sleep $((5**$i));
			continue;
		else
			success=1
			break;
		fi
	done
	if [ $success -ne 1 ]; then
		unsuccessful_exit "Unable to get data from url $url after $numAttempt number of attempts." 68
	fi

    echo $output;
}













