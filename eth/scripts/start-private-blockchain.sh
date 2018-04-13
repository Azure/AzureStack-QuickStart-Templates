#!/bin/bash

#############
# Parameters
#############
if [ $# -lt 2 ]; then echo "Incomplete parameters supplied. usage: \"$0 <config file path> <ethereum account passwd>\""; exit 1; fi
GETH_CFG=$1;
PASSWD=$2;
IP_TO_PING=$3;

########################
# Load config variables
########################
if [ ! -e $GETH_CFG ]; then echo "Config file not found. Exiting"; exit 1; fi
. $GETH_CFG

#############
# Constants
#############
ETHERADMIN_LOG_FILE_PATH="$HOMEDIR/etheradmin.log";
# Log level of geth
VERBOSITY=4;

###########################################
# Ensure that at least one bootnode is up
# If not, wait 5 seconds then retry
###########################################
FOUND_BOOTNODE=false
while sleep 5; do
	for i in `seq 0 $(($NUM_BOOT_NODES - 1))`; do
		if [ `hostname` = $MN_NODE_PREFIX$i ]; then
			continue
		fi

		LOOKUP=`nslookup $MN_NODE_PREFIX$i | grep "can't find"`
		if [ -z $LOOKUP ]; then
			FOUND_BOOTNODE=true
			break
		fi
	done

	if [ "$FOUND_BOOTNODE" = true ]; then
		break
	fi
done

#####################################################
# Replace hostnames in config file with IP addresses
#####################################################
BOOTNODE_URLS=`echo $BOOTNODE_URLS | perl -pe 's/#(.*?)#/qx\/nslookup $1| egrep "Address: [0-9]"| cut -d" " -f2 | xargs echo -n\//ge'`

############################################################
# Make boot node urls available to other consortium members
############################################################
if [ $NODE_TYPE -eq 0 ]; then
  printf "%s" "$BOOTNODE_URLS" > $BOOTNODE_SHARE_PATH; # overwrite, don't append
fi

######################################
# Get IP address for geth RPC binding
######################################
IPADDR=`ifconfig eth0 | grep "inet addr" | cut -d ':' -f 2 | cut -d ' ' -f 1`;

############################
# Only mine on mining nodes
############################
if [ $NODE_TYPE -ne 0 ]; then
  MINE_OPTIONS="--mine --minerthreads $MINER_THREADS";
else
  FAST_SYNC="--fast";
fi

##########################################
# Startup admin site if this is a TX Node
##########################################
if [ $NODE_TYPE -eq 0 ]; then
  cd $ETHERADMIN_HOME;
  echo "===== Starting admin webserver =====";
  nohup nodejs app.js $ADMIN_SITE_PORT $GETH_HOME/geth.ipc $PREFUND_ADDRESS $PASSWD $MN_NODE_PREFIX $NUM_MN_NODES $TX_NODE_PREFIX $NUM_TX_NODES $CONSORTIUM_MEMBER_ID >> $ETHERADMIN_LOG_FILE_PATH 2>&1 &
  if [ $? -ne 0 ]; then echo "Previous command failed. Exiting"; exit $?; fi
  echo "===== Started admin webserver =====";
fi
echo "===== Completed $0 =====";


############
# Spin until connection has been established
############
while [ ${#IP_TO_PING} -gt 0 ]
do
	ping -c 1 $IP_TO_PING > /dev/null

	if [ $? -eq 0 ]
	then
		echo "connection established"
		break
	fi

	sleep 60
done

##################
# Start geth node
##################
echo "===== Starting geth node =====";
set -x;
nohup geth --datadir $GETH_HOME -verbosity $VERBOSITY $BOOTNODE_URLS --maxpeers $MAX_PEERS --nat none --networkid $NETWORK_ID --identity $IDENTITY $MINE_OPTIONS $FAST_SYNC --rpc --rpcaddr "$IPADDR" --rpccorsdomain "*" >> $GETH_LOG_FILE_PATH 2>&1 &
if [ $? -ne 0 ]; then echo "Previous command failed. Exiting"; exit $?; fi
set +x;
echo "===== Started geth node =====";

