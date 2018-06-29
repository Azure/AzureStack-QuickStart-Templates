#!/bin/bash
source deployment-utility.sh
echo "===== Initializing geth installation =====";
date;

############
# Parameters
############
# Validate that all arguments are supplied
if [ $# -lt 14 ]; then echo "Insufficient parameters supplied. Exiting"; exit 1; fi

AZUREUSER=$1;
PASSWD=$2;
PASSPHRASE=$3;
ARTIFACTS_URL_PREFIX=$4;
NETWORK_ID=$5;
MAX_PEERS=$6;
NODE_TYPE=$7;               # (0=Transaction node; 1=Mining node )
GETH_IPC_PORT=$8;
NUM_BOOT_NODES=$9;
NUM_MN_NODES=${10};
MN_NODE_PREFIX=${11};
SPECIFIED_GENESIS_BLOCK=${12};
ADMIN_HASH=${13};
MN_NODE_SEQNUM=${14};       #Only supplied for NODE_TYPE=1
NUM_TX_NODES=${14};         #Only supplied for NODE_TYPE=0
TX_NODE_PREFIX=${15};       #Only supplied for NODE_TYPE=0
ADMIN_SITE_PORT=${16};      #Only supplied for NODE_TYPE=0
CONSORTIUM_MEMBER_ID=${17}; #Only supplied for NODE_TYPE=0

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
# Difficulty constant represents ~15 sec. block generation for one node
DIFFICULTY_CONSTANT="0x3333";
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

cd $HOMEDIR;

setup_dependencies
setup_node_info
echo $BOOTNODE_URLS

##############################################
# Did we get a genesis file specified?  if so decode the base64
# Otherwise we need to create one
##############################################
if [ ${#SPECIFIED_GENESIS_BLOCK} -gt 0 ]; then
	# Genesis block comes in as base64, need to decode it
	SPECIFIED_GENESIS_BLOCK=`echo ${SPECIFIED_GENESIS_BLOCK} | base64 --decode`;
	echo ${SPECIFIED_GENESIS_BLOCK} > $GENESIS_FILE_PATH;
fi

##############################################
# only the transaction nodes need to create the private key
##############################################
if [ ${#SPECIFIED_GENESIS_BLOCK} -gt 0 ]; then	
	echo "===========================Genesis block specified===========================";
	# ADMIN_HASH serves as the password and a salt for deriving the private key
	PASSWD_FILE="$GETH_HOME/passwd.info";
	PASSWD=$ADMIN_HASH;
	printf %s $ADMIN_HASH > $PASSWD_FILE;
	
	# PRIV_KEY for the admin site is derived from genesis block and the admin hash which is derived from the admin password
	PRIV_KEY=`echo "$SPECIFIED_GENESIS_BLOCK$ADMIN_HASH" | sha256sum | sed s/-// | sed "s/ //"`;
	printf "%s" $PRIV_KEY > $HOMEDIR/priv_genesis.key;
	PREFUND_ADDRESS=`geth --datadir $GETH_HOME --password $PASSWD_FILE account import $HOMEDIR/priv_genesis.key | grep -oP '\{\K[^}]+'`;
	rm $HOMEDIR/priv_genesis.key;
	rm $PASSWD_FILE;
	cd $HOMEDIR
else
	##############################################
	# Setup Genesis file and pre-allocated account
	##############################################
	setup_system_ethereum_account
	
	
	cd $HOMEDIR
	wget -N ${ARTIFACTS_URL_PREFIX}/genesis-template.json || exit 1;
	# Scale difficulty: Target difficulty scales with number of miners
	DIFFICULTY=`printf "0x%X" $(($DIFFICULTY_CONSTANT * $NUM_MN_NODES))`;
	# Place our calculated difficulty into genesis file
	sed s/#DIFFICULTY/$DIFFICULTY/ $HOMEDIR/genesis-template.json > $HOMEDIR/genesis-intermediate.json;
	sed s/#NETWORKID/$NETWORK_ID/ $HOMEDIR/genesis-intermediate.json > $HOMEDIR/genesis-intermediate2.json;
	sed s/#PREFUND_ADDRESS/$PREFUND_ADDRESS/ $HOMEDIR/genesis-intermediate2.json > $GENESIS_FILE_PATH;
fi

initialize_geth
setup_admin_website
create_config
setup_rc_local

############
# Start geth
############
cd $HOMEDIR;
wget -N ${ARTIFACTS_URL_PREFIX}/scripts/start-private-blockchain.sh || exit 1;
/bin/bash $HOMEDIR/start-private-blockchain.sh $GETH_CFG_FILE_PATH $PASSWD "" || exit 1;
echo "Commands succeeded. Exiting";
exit 0;