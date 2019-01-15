#!/bin/bash

#############################################################################################################
# Bootstraps orchestration -- This script will be executed in the Dockerfile to start orchestration process
##############################################################################################################

CONFIG_LOG_FILE_PATH="/var/log/deployment/config.log"
sudo ./orchestrate-poa.sh "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}" "${14}" "${15}" "${16}" "${17}">> "$CONFIG_LOG_FILE_PATH" 2>&1;