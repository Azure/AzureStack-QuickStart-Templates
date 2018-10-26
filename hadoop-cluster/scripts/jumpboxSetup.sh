#!/bin/bash
#
# Jumpbox setup
#
#	This will setup the jumpbox and also configure each hadoop node
#

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' EXIT SIGHUP SIGINT SIGQUIT
exec 1>> /mnt/hadoop_extension.log 2>&1
# Everything below will go to the file 'hadoop_extension.log':

# Output commands and disable history expansion
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x +H

# Reverse DNS fix
IP=`hostname -I`
HOST=`hostname`
echo -n "$IP $HOST" >> /etc/hosts

# Helper
function Log() {
    echo -e "$(date '+%d/%m/%Y %H:%M:%S:%3N'): $1"
}

############################################################
#
# 	Constants
#
#

#
#   System constants
#

# Mount location (not really needed)
MOUNT=/hadoop
# Name of the machine
HOSTNAME=`hostname`
# Admin user account
ADMIN_USER=`ls /home/`
# Name of the cluster
CLUSTER_NAME=`hostname | sed 's/Jumpbox$//g'`

#
#   Hadoop Constants
#

# Hadoop Home Location
HADOOP_HOME=/usr/local/hadoop
# Default hadoop user
HADOOP_USER="hadoop"
# Local hadoop archive
HADOOP_FILE_NAME="hadoop.tar.gz"
# Get the role of this node
USERS=("hdfs" "mapred" "yarn")


############################################################
#
#	Variables from input
#
#

# How many worker nodes
NUMBER_NODES="$1"

# How many worker nodes
ADMIN_PASSWORD="$2"

REPLICATION="$3"

# Check to see if ADMIN_USER has been passed in
if [ $# -eq 5 ]; then
    ADMIN_USER="$4"
fi

############################################################
#
# 	Create the list of master and worker nodes in the
#	cluster
#

MASTER_NODES=("${CLUSTER_NAME}NameNode" "${CLUSTER_NAME}ResourceManager" "${CLUSTER_NAME}JobHistory")

WORKER_NODES=()
for i in `seq 0 $((NUMBER_NODES - 1))`;
do
    worker="${CLUSTER_NAME}Worker$i"
    WORKER_NODES[$((i + 4))]=$worker
done


############################################################
#
# 	Create the list of master and worker nodes in the
#	cluster
#
preinstall () {
    # Install avahi-daemon and Java Runtime Environment
    apt-get update > /dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet default-jre htop sshpass > /dev/null

    # Setup JAVA
    JAVA_HOME=`readlink -f /usr/bin/java | sed 's:/bin/java::'`
    echo -e "export JAVA_HOME=$JAVA_HOME" >> /etc/profile.d/java.sh
}

add_hadoop_user () {
    Log "Creating user $HADOOP_USER"

    addgroup "hadoop"

    # Create user
    useradd -m -g hadoop -s /bin/bash $HADOOP_USER

    # Location of SSH files
    local SSH_DIR=/home/$HADOOP_USER/.ssh

    # Create directory
    mkdir -p $SSH_DIR

    # Key name
    local KEY_NAME=$SSH_DIR/id_rsa

    # Generate key with empty passphrase
    ssh-keygen -t rsa -N "" -f $KEY_NAME

    # Add to my own authorized keys for loopback
    cat $SSH_DIR/id_rsa.pub >> $SSH_DIR/authorized_keys

    # Disable key checking
    echo -e "Host *" >> /home/$HADOOP_USER/.ssh/config
    echo -e "    StrictHostKeyChecking no" >> /home/$HADOOP_USER/.ssh/config

    # They own their own home directory and everything under it
    chown -R $HADOOP_USER:$HADOOP_USER /home/$HADOOP_USER -R
}


############################################################
#
# 	Copy public keys from all nodes to all other nodes.
#
copy_users () {
    local TMP_FILE='local_authorized_keys'
    # Create empty file
    > $TMP_FILE

    # Create local authorized_keys
    for FROM in ${WORKER_NODES[@]}; do
        for U in ${USERS[@]}; do
            Log "Copy public key from $FROM"
            sshpass -p $ADMIN_PASSWORD scp -o StrictHostKeyChecking=no $ADMIN_USER@$FROM:/home/$U/.ssh/id_rsa.pub .

            Log "Append to $TMP_FILE"
            cat id_rsa.pub >> $TMP_FILE

            Log "Remove copied public key"
            rm -f id_rsa.pub
        done
    done

    # Copy to remove nodes
    for TO in ${MASTER_NODES[@]}; do
        for U in ${USERS[@]}; do
            Log "Add to remote authorized_keys on host $TO for user $U"
            cat $TMP_FILE | sshpass -p $ADMIN_PASSWORD ssh -o StrictHostKeyChecking=no $ADMIN_USER@$TO "sudo tee -a /home/$U/.ssh/authorized_keys" > /dev/null
        done
    done

    Log "Remove $TMP_FILE file"
    rm $TMP_FILE
}

############################################################
#
# 	Restart each node in the Hadoop cluster.  This will
#   cause Hadoop to start on each node.
#
restart_nodes () {
    # Add this to task scheduler
    local REBOOT_CMD='echo "sleep 5 && sudo reboot" | at now'

    # Restart masters
    for N in ${MASTER_NODES[@]}; do
        Log "Restarting node $N"
        sshpass -p $ADMIN_PASSWORD ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 $ADMIN_USER@$N $REBOOT_CMD > /dev/null
    done

    # Restart workers
    for N in ${WORKER_NODES[@]}; do
        Log "Restarting node $N"
        sshpass -p $ADMIN_PASSWORD ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 $ADMIN_USER@$N $REBOOT_CMD > /dev/null
    done
}


############################################################
#
#	Downloads and extracts hadoop into the correct folder
#
#

install_hadoop () {

    # Download Hadoop from a random source
    local RET_ERR=1
    while [[ $RET_ERR -ne 0 ]];
    do
        local HADOOP_URI=`shuf -n 1 sources.txt`
        Log "Downloading from $HADOOP_URI"
        timeout 120 wget --timeout 30 "$HADOOP_URI" -O "$HADOOP_FILE_NAME" > /dev/null
        RET_ERR=$?
    done

    # Extract
    tar -xvzf $HADOOP_FILE_NAME > /dev/null
    rm $HADOOP_FILE_NAME

    # Move files to /usr/local
    mkdir -p ${HADOOP_HOME}
    mv hadoop-2.9.0/* ${HADOOP_HOME}

    # Create log directory with permissions
    mkdir ${HADOOP_HOME}/logs
    chmod 774 ${HADOOP_HOME}/logs

    # Copy configuration files
    cp *.xml ${HADOOP_HOME}/etc/hadoop/ -f

    # Update hadoop configuration
    sed -i -e "s+CLUSTER_NAME+$CLUSTER_NAME+g" $HADOOP_HOME/etc/hadoop/core-site.xml
    sed -i -e "s+MOUNT_LOCATION+$MOUNT+g" $HADOOP_HOME/etc/hadoop/core-site.xml

    sed -i -e "s+CLUSTER_NAME+$CLUSTER_NAME+g" $HADOOP_HOME/etc/hadoop/hdfs-site.xml
    sed -i -e "s+REPLICATION+$REPLICATION+g" $HADOOP_HOME/etc/hadoop/hdfs-site.xml

    sed -i -e "s+CLUSTER_NAME+$CLUSTER_NAME+g" $HADOOP_HOME/etc/hadoop/yarn-site.xml

    sed -i -e "s+\${JAVA_HOME}+'$JAVA_HOME'+g" $HADOOP_HOME/etc/hadoop/hadoop-env.sh

sed -i -e "s+REPLICATION+$REPLICATION+g" $HADOOP_HOME/etc/hadoop/mapred-site.xml
    #
    # Global profile environment variables
    #
    echo -e "export HADOOP_HOME=$HADOOP_HOME"                       >> /etc/profile.d/hadoop.sh
    echo -e 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin'  >> /etc/profile.d/hadoop.sh

    # Hadoop group owns hadoop installation
    chown $ADMIN_USER:hadoop -R $HADOOP_HOME

    # Hadoop group can do anything owner can do
    chmod 664 $HADOOP_HOME/etc/hadoop/*
    chmod -R g=u $HADOOP_HOME
}


# Pre-install all required programs
preinstall

# Add the hadoop user so we can submit jobs from here
add_hadoop_user

# Copy public keys around
copy_users

# Restart all Hadoop nodes
restart_nodes

# install hadoop.
install_hadoop

Log "Success"
exit 0
