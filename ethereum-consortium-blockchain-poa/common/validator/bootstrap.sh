#!/bin/bash

#############################################################################################################
# Run validator node -- This script will be executed in the Dockerfile to start validation process
##############################################################################################################

CONFIG_LOG_FILE_PATH=${15}
PARITY_LOG_FILE_PATH=${16}
SLEEP_INTERVAL_IN_SECS=180
AZUREUSER=$1;
HOMEDIR="/home/$AZUREUSER"

cp validator.sh $HOMEDIR
cp node.toml $HOMEDIR
cp none_authority.toml $HOMEDIR

# Replace parity log path in config file
sed -i s#LOG_PATH#$PARITY_LOG_FILE_PATH# parity_log_config
cp parity_log_config /etc/logrotate.d/parity

cd $HOMEDIR

sudo ./validator.sh "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}" "${14}" "${16}" >> $CONFIG_LOG_FILE_PATH 2>&1 &

validator_pid=$!
if wait $validator_pid; then
        echo "Validator process successfully started parity and exited."
else
        echo "Validator process has failed. Exiting ..."
        exit 1;
fi

# TODO: temporary fix to keep the process running. Otherwise docker will exit and the validator stops. Find a permanant solution for this issue.
# if renew & acquire license is moved to this docker container, this won't be necessary
while sleep $SLEEP_INTERVAL_IN_SECS; do

    echo " running validator ..."

done