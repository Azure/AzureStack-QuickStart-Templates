#!/bin/bash

# Utility function to exit with message
unsuccessful_exit()
{
  echo "FATAL: Exiting script due to: $1, error code: $2" | tee -a $CONFIG_LOG_FILE_PATH;
}

#####################################################################################
# Log Folder Locations
#####################################################################################
DEPLOYMENT_LOG_PATH="/var/log/deployment"
CONFIG_LOG_FILE_PATH="$DEPLOYMENT_LOG_PATH/config.log";

if [ $# -lt 3 ]; then unsuccessful_exit "Insufficient parameters supplied." 1; fi

USER_EMAIL=$1
ETHERADMIN_URL=$2
RPC_ENDPOINT=$3
OMS_DASHBOARD=$4
CONSORTIUM_DATA_URL=$5
GATEWAY_ID=$6

emailProxyEndpoint="https://blockchaindeploymentnotification.azurewebsites.net/api/EmailProxyWebhook?code=twKKOBIJ3bTE/CEHYdln1VvNq8wTfiTQN4Ij83PNMlQdyJrPWdrOhQ=="

curl --data "{'email':'$USER_EMAIL', 
              'etheradmin':'$ETHERADMIN_URL', 
              'rpc':'$RPC_ENDPOINT', 
              'oms':'$OMS_DASHBOARD', 
              'consortiumUrl':'$CONSORTIUM_DATA_URL', 
              'gatewayId':'$GATEWAY_ID' }" $emailProxyEndpoint