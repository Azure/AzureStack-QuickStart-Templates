#!/bin/bash

############################################################
#
# 	Node setup script
#
#	This will setup hadoop on the node.  This also
#	formats and mounts the data-disk as well.
#


############################################################
#
# 	Enable logging.
#

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' EXIT SIGHUP SIGINT SIGQUIT
exec 1>>/mnt/hadoop_extension.log 2>&1

# Output commands and disable history expansion
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
set -x +H


# Reverse DNS fix
IP=`hostname -I`
HOST=`hostname`
echo -n "$IP $HOST" >> /etc/hosts

function Log() {
    echo -e "$(date '+%d/%m/%Y %H:%M:%S:%3N'): $1"
}

function check_error() {
    RET=$1
    MSG=$MSG
    if [ $RET -ne 0 ]; then
        Log "[ERROR] $MSG"
        exit 1
    fi
}

############################################################
#
# 	Parameters
#
#
WORKERS=$1

############################################################
#
# 	Constants
#
#

#
#   System constants
#

#
# Regular expressions to extract the ClusterName
#
JHREG='\(JobHistory$\)'
NNREG='\(NameNode$\)'
RMREG='\(ResourceManager$\)'
WKREG='\(Worker[0-9]\+$\)'
# Name of the cluster
CLUSTER_NAME=`hostname | sed "s/$JHREG\|$NNREG\|$RMREG\|$WKREG//g"`
# Admin USER
ADMIN_USER=`ls /home/`
# Where we mount the data disk
MOUNT=/hadoop

#
#   Hadoop constants
#

# What we want to call the hadoop archive locally
HADOOP_FILE_NAME="hadoop.tar.gz"
# Hadoop users
USERS=("hadoop" "hdfs" "mapred" "yarn")
# Hadoop home
HADOOP_HOME=/usr/local/hadoop
# Get the role of this node
ROLE=`hostname`

############################################################
#
# 	Install pre-reqs
#
#
preinstall () {
    # Add mirrors,

    # Create backup
    SOURCES='/etc/apt/sources.list'
    cp "$SOURCES" "$SOURCES.bak"
    echo 'deb mirror://mirrors.ubuntu.com/mirrors.txt precise main restricted universe multiverse'              | cat - $SOURCES > /tmp/sources.list && mv /tmp/sources.list $SOURCES
    echo 'deb mirror://mirrors.ubuntu.com/mirrors.txt precise-updates main restricted universe multiverse'      | cat - $SOURCES > /tmp/sources.list && mv /tmp/sources.list $SOURCES
    echo 'deb mirror://mirrors.ubuntu.com/mirrors.txt precise-backports main restricted universe multiverse'    | cat - $SOURCES > /tmp/sources.list && mv /tmp/sources.list $SOURCES
    echo 'deb mirror://mirrors.ubuntu.com/mirrors.txt precise-security main restricted universe multiverse'     | cat - $SOURCES > /tmp/sources.list && mv /tmp/sources.list $SOURCES

    # Java Runtime Environment
    apt-get update > /dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet default-jre htop sshpass > /dev/null
    check_error $? "Could not install pre-reqs"

    # Setup JAVA
    JAVA_HOME=`readlink -f /usr/bin/java | sed 's:/bin/java::'`
    echo -e "export JAVA_HOME=$JAVA_HOME" >> /etc/profile.d/java.sh
    check_error $? "Could not add JAVA_HOME to profile"
}

############################################################
#
# 	Attach and format the disk, save config to FSTAB
#
#

attach_disks () {

    #
    # Locate the datadisk
    #

    Log "Everything under /dev\n$(ls /dev)"

    # List all disks.
    Log "lsblk: \n$(lsblk)"

    local DISKS=`lsblk -d | grep "disk" | awk -F ' ' '{print $1}'`
    Log "DISKS=$DISKS"

    # List all partitions.
    local PARTS=`lsblk | grep part`
    Log "PARTS=$PARTS"

    # Get the disk without any partitions.
    local DD=`for d in $DISKS; do echo $PARTS | grep -vo $d && echo $d; done`
    Log "DD=$DD"

    #
    # Format/Create partitions
    #

    Log "Creating label"
    local n=0
    until [ $n -ge 5 ];
    do
        parted /dev/$DD mklabel gpt && break
        n=$[$n + 1]
        Log "Label creation failures $n"
        sleep 10
    done

    Log "Creating partition"
    n=0
    until [ $n -ge 5 ];
    do
        parted -a opt /dev/$DD mkpart primary ext4 0% 100% && break
        n=$[$n + 1]
        Log "Partition creation failures $n"
        sleep 10
    done

    # write file-system lazily for performance reasons.
    n=0
    until [ $n -ge 5 ];
    do
        mkfs.ext4 -L datapartition /dev/${DD}1 -F && break
        n=$[$n + 1]
        Log "FS creation failures $n"
        sleep 10
    done

    # Create mount point
    mkdir $MOUNT -p

    #
    # Add to FSTAB
    #

    # Get the UUID
    blkid -s none
    local UUID=`blkid -s UUID -o value /dev/${DD}1`
    local LINE=""

    if [ -z "$UUID" ]; then
        # Fall back to disk
        LINE="$/dev/${DD}1\t$MOUNT\text4\tnoatime,nodiratime,nodev,noexec,nosuid\t1 2"
    else
        # Use UUID
        LINE="UUID=$UUID\t$MOUNT\text4\tnoatime,nodiratime,nodev,noexec,nosuid\t1 2"
    fi

    Log "Adding '$LINE' to FSTAB"
    echo -e "$LINE" >> /etc/fstab

    # mount
    mount $MOUNT
    check_error $? "Could not mount $DD to $MOUNT"
}

############################################################
#
# 	Add users for hadoop
#
#

add_users () {

    # Create hadoop user and group
    addgroup "hadoop"

    # Create users and keys
    for user in "${USERS[@]}";
    do

        Log "Creating user $user"

        # Create user
        useradd -m -g hadoop -s /bin/bash $user
        check_error $? "Could not create user $user"

        # Location of SSH files
        local SSH_DIR=/home/$user/.ssh

        # Create directory
        mkdir -p $SSH_DIR

        # Key name
        local KEY_NAME=$SSH_DIR/id_rsa

        # Generate key with empty passphrase
        ssh-keygen -t rsa -N "" -f $KEY_NAME
        check_error $? "Could not generate key for $user"

        # Add to my own authorized keys
        cat $SSH_DIR/id_rsa.pub >> $SSH_DIR/authorized_keys

        # Disable key checking
        echo -e "Host *" >> /home/$user/.ssh/config
        echo -e "    StrictHostKeyChecking no" >> /home/$user/.ssh/config

        chown -R $user:$user /home/$user
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
    check_error $? "Could not extract Hadoop"

    # Move files to /usr/local
    mkdir -p ${HADOOP_HOME}
    mv hadoop-2.9.0/* ${HADOOP_HOME}
    check_error $? "Could not move files to $HADOOP_HOME"

    # Create log directory with permissions
    mkdir ${HADOOP_HOME}/logs
    chmod 774 ${HADOOP_HOME}/logs

    # Create azure directory with permissions
    mkdir ${HADOOP_HOME}/azure
    chmod 774 ${HADOOP_HOME}/azure

    # Copy configuration files
    cp *.xml ${HADOOP_HOME}/etc/hadoop/ -f

    # Update hadoop configuration
    sed -i -e "s+CLUSTER_NAME+$CLUSTER_NAME+g" $HADOOP_HOME/etc/hadoop/core-site.xml
    sed -i -e "s+MOUNT_LOCATION+$MOUNT+g" $HADOOP_HOME/etc/hadoop/core-site.xml

    sed -i -e "s+CLUSTER_NAME+$CLUSTER_NAME+g" $HADOOP_HOME/etc/hadoop/hdfs-site.xml

    sed -i -e "s+CLUSTER_NAME+$CLUSTER_NAME+g" $HADOOP_HOME/etc/hadoop/yarn-site.xml

    sed -i -e "s+\${JAVA_HOME}+'$JAVA_HOME'+g" $HADOOP_HOME/etc/hadoop/hadoop-env.sh

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

    # HDFS user and hadoop group owns everything on the data disk
    chown hdfs:hadoop -R $MOUNT
    chmod -R g=u $MOUNT
}


############################################################
#
# 	Create configuration files and set to startup at boot
#
#

setup_node () {

    # Create a service and restart it
    function create_service() {

        local NAME=$1
        local USER=$2
        local SERVICE=$3

        local FILENAME="$NAME.service"
        local START=$HADOOP_HOME/azure/start-$NAME.sh
        local STOP=$HADOOP_HOME/azure/stop-$NAME.sh
        local PID="/tmp/$SERVICE-$USER-$NAME.pid"

        # Create
        cp template.service $FILENAME

        # Update
        sed -i -e "s+SED_USER+$USER+g" $FILENAME
        sed -i -e "s+SED_START+$START+g" $FILENAME
        sed -i -e "s+SED_STOP+$STOP+g" $FILENAME
        sed -i -e "s+SED_JAVA_HOME+$JAVA_HOME+g" $FILENAME
        sed -i -e "s+SED_PID+$PID+g" $FILENAME
        sed -i -e "s+SED_HADOOP_HOME+$HADOOP_HOME+g" $FILENAME

        # Install
        mv $FILENAME /etc/systemd/system/
        chmod 755  /etc/systemd/system/$FILENAME

        # Load, enable, and start service
        systemctl daemon-reload
        systemctl enable $FILENAME
        systemctl start $FILENAME
    }

    setup_master() {
        # Create slaves file
        > $HADOOP_HOME/etc/hadoop/slaves
        for i in `seq 0 $((WORKERS - 1))`;
        do
            echo "${CLUSTER_NAME}Worker${i}" >> $HADOOP_HOME/etc/hadoop/slaves
        done
    }

    # Create directories and persmissions
    setup_namenode() {

        local HDFS="${HADOOP_HOME}/bin/hdfs"

        # format HDFS
        sudo -u hdfs -i ${HDFS} namenode -format
        check_error $? "Could not format NameNode"

        # Start HDFS Namenode
        sudo -u hdfs -i $HADOOP_HOME/sbin/hadoop-daemon.sh --script hdfs start namenode
        check_error $? "Could not start NameNode"

        # Create tmp directory
        sudo -u hdfs -i ${HDFS} dfs -mkdir /tmp
        check_error $? "Could not create the HDFS directory /tmp"

        sudo -u hdfs -i ${HDFS} dfs -chmod 777 /tmp
        check_error $? "Could not chmod the HDFS directory /tmp"

        # Create home directory
        sudo -u hdfs -i ${HDFS} dfs -mkdir /home
        check_error $? "Could not create the HDFS directory /home"

        sudo -u hdfs -i ${HDFS} dfs -chmod 775 /home
        check_error $? "Could not chmod the HDFS directory /home"

        # Create user directories
        for user in "${USERS[@]}";
        do
            sudo -u hdfs -i ${HDFS} dfs -mkdir /home/$user
            check_error $? "Could not create the HDFS directory /home/$user"

            sudo -u hdfs -i ${HDFS} dfs -chown $user /home/$user
            check_error $? "Could not change the HDFS directory /home/$user owner"

            sudo -u hdfs -i ${HDFS} dfs -chmod 700 /home/$user
            check_error $? "Could not chmod the HDFS directory /home/$user"
        done

        # Stop HDFS Namenode
        sudo -u hdfs -i $HADOOP_HOME/sbin/hadoop-daemon.sh --script hdfs stop namenode

    }

    echo -e 'soft nofile 38768' >> /etc/security/limits.conf
    echo -e 'hard nofile 38768' >> /etc/security/limits.conf
    echo -e 'soft nproc 38768' >> /etc/security/limits.conf
    echo -e 'hard nproc 38768' >> /etc/security/limits.conf

    echo -e '
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
   echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
   echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
    ' >> /etc/rc.local


    if [[ $ROLE =~ Worker ]];
    then

        # Resource Node
        echo -e "#!/bin/bash\n/usr/local/hadoop/sbin/yarn-daemon.sh start nodemanager" > $HADOOP_HOME/azure/start-nodemanager.sh
        echo -e "#!/bin/bash\n/usr/local/hadoop/sbin/yarn-daemon.sh stop nodemanager" > $HADOOP_HOME/azure/stop-nodemanager.sh
        create_service 'nodemanager' 'yarn' 'yarn'

        # Data Node
        echo -e "#!/bin/bash\n/usr/local/hadoop/sbin/hadoop-daemon.sh --script hdfs start datanode" > $HADOOP_HOME/azure/start-datanode.sh
        echo -e "#!/bin/bash\n/usr/local/hadoop/sbin/hadoop-daemon.sh --script hdfs stop datanode" > $HADOOP_HOME/azure/stop-datanode.sh
        create_service 'datanode' 'hdfs' 'hadoop'

    elif [[ $ROLE =~ NameNode ]];
    then
        setup_master
        setup_namenode

        echo -e "#!/bin/bash\n/usr/local/hadoop/sbin/hadoop-daemon.sh --script hdfs start namenode" > $HADOOP_HOME/azure/start-namenode.sh
        echo -e "#!/bin/bash\n/usr/local/hadoop/sbin/hadoop-daemon.sh --script hdfs stop namenode" > $HADOOP_HOME/azure/stop-namenode.sh
        create_service 'namenode' 'hdfs' 'hadoop'

    elif [[ $ROLE =~ ResourceManager ]];
    then
        setup_master

        echo -e "#!/bin/bash\n/usr/local/hadoop/sbin/yarn-daemon.sh start resourcemanager" > $HADOOP_HOME/azure/start-resourcemanager.sh
        echo -e "#!/bin/bash\n/usr/local/hadoop/sbin/yarn-daemon.sh stop resourcemanager" > $HADOOP_HOME/azure/stop-resourcemanager.sh
        create_service 'resourcemanager' 'yarn' 'yarn'

    elif [[ $ROLE =~ JobHistory ]];
    then
        setup_master

        echo -e "#!/bin/bash\n/usr/local/hadoop/sbin/mr-jobhistory-daemon.sh start historyserver" > $HADOOP_HOME/azure/start-historyserver.sh
        echo -e "#!/bin/bash\n/usr/local/hadoop/sbin/mr-jobhistory-daemon.sh stop historyserver" > $HADOOP_HOME/azure/stop-historyserver.sh
        create_service 'historyserver' 'mapred' 'mapred'

    else
        Log "Invalid Role $ROLE"
        exit 999
    fi

    chown $ADMIN_USER:hadoop $HADOOP_HOME/azure -R
    chmod 555 $HADOOP_HOME/azure/*.sh
}

############################################################
#
#	Run the functions above.
#
#

# Pre-install all required programs
if [ ! -f pre_status ];
then
    preinstall
    echo 'DONE' >> pre_status
fi

# Attach all data disks
if [ ! -f disk_status ];
then
    attach_disks
    echo 'DONE' >> disk_status
fi

# Add all Hadoop users
if [ ! -f user_status ];
then
    add_users
    echo 'DONE' >> user_status
fi

# Install hadoop
if [ ! -f hadoop_status ];
then
    install_hadoop
    echo 'DONE' >> hadoop_status
fi

# Setup this node for hadoop
if [ ! -f setup_status ];
then
    setup_node
    echo 'DONE' >> setup_status
fi

Log "Success"

exit 0
