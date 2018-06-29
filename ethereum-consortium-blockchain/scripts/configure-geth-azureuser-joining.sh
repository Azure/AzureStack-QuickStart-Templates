#!/bin/bash
source deployment-utility.sh
echo "===== Initializing geth installation =====";
date;

############
# Parameters
############
# Validate that all arguments are supplied
if [ $# -lt 12 ]; then echo "Insufficient parameters supplied. Exiting"; exit 1; fi

AZUREUSER=$1;
PASSWD=$2;
PASSPHRASE=$3;
ARTIFACTS_URL_PREFIX=$4;
CONSORTIUM_DATA_ROOT=$5;
MAX_PEERS=$6;
NODE_TYPE=$7;               # (0=Transaction node; 1=Mining node )
GETH_IPC_PORT=$8;
NUM_BOOT_NODES=$9;
NUM_MN_NODES=${10};
MN_NODE_PREFIX=${11};
MN_NODE_SEQNUM=${12};       #Only supplied for NODE_TYPE=1
NUM_TX_NODES=${12};         #Only supplied for NODE_TYPE=0
TX_NODE_PREFIX=${13};       #Only supplied for NODE_TYPE=0
ADMIN_SITE_PORT=${14};      #Only supplied for NODE_TYPE=0
CONSORTIUM_MEMBER_ID=${15}; #Only supplied for NODE_TYPE=0

#############
# Globals
#############
declare -a NODE_KEYS
PREFUND_ADDRESS=""
BOOTNODE_URLS="";

#############
# Constants
#############
MINER_THREADS=1;
HOMEDIR="/home/$AZUREUSER";
VMNAME=`hostname`;
GETH_HOME="$HOMEDIR/.ethereum";
mkdir -p $GETH_HOME;
ETHERADMIN_HOME="$HOMEDIR/etheradmin";
GETH_LOG_FILE_PATH="$HOMEDIR/geth.log";
GENESIS_FILE_PATH="$HOMEDIR/genesis.json";
GETH_CFG_FILE_PATH="$HOMEDIR/geth.cfg";
NODEKEY_SHARE_PATH="$GETH_HOME/nodekey";
BOOTNODE_SHARE_PATH="$ETHERADMIN_HOME/public/bootnodes.txt"
NETWORKID_SHARE_PATH="$ETHERADMIN_HOME/public/networkid.txt"

# Below information will be loaded from another consortium member
REMOTE_BOOTNODE_URL="$CONSORTIUM_DATA_ROOT/bootnodes.txt";
REMOTE_GENESIS_BLOCK_URL="$CONSORTIUM_DATA_ROOT/genesis.json";
REMOTE_NETWORK_ID_URL="$CONSORTIUM_DATA_ROOT/networkid.txt";

echo "CONSORTIUM_DATA_ROOT = "$CONSORTIUM_DATA_ROOT;

cd $HOMEDIR;

setup_dependencies
setup_node_info

#########################################
# Download Boot Node Urls of other member and get IP to 
# append to bootnodes.txt
#########################################
wget -N ${REMOTE_BOOTNODE_URL} || exit 1;
IP_TO_PING=$(grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' bootnodes.txt | head -1)

REMOTE_BOOTNODE_URLS=`cat bootnodes.txt`;
BOOTNODE_URLS="${BOOTNODE_URLS} ${REMOTE_BOOTNODE_URLS}";

#########################################
# Setup ethereum account for the system
#########################################
setup_system_ethereum_account

##################################
# Download the genesis block file
##################################
cd $HOMEDIR;
sudo /bin/bash -c "wget -N ${REMOTE_GENESIS_BLOCK_URL}";

##################################
# Download and read the NetworkId
##################################
wget -N ${REMOTE_NETWORK_ID_URL} || exit 140;
NETWORK_ID=`cat networkid.txt`;

initialize_geth
setup_admin_website
create_config
setup_rc_local

############
# Start geth
############
cd $HOMEDIR;
wget -N ${ARTIFACTS_URL_PREFIX}/scripts/start-private-blockchain.sh || exit 1;
nohup /bin/bash $HOMEDIR/start-private-blockchain.sh $GETH_CFG_FILE_PATH $PASSWD $IP_TO_PING &
echo "Commands succeeded. Exiting";
exit 0;