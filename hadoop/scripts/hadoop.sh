#!/bin/bash

### BEGIN INIT INFO
# Provides :    Hadoop
# Required-Start :
# Required-Stop :
# Default-Start :
# Default-Stop :
# Short-Description : ensure Hadoop daemons are started.
### END INIT INFO

set -e

# Load stuff
source /etc/profile

ROLE='UNKNOWN'
HOST=`hostname`

if [[ "$HOST" =~ "NameNode" ]];
then
    ROLE='NameNode'
elif [[ "$HOST" =~ "ResourceManager" ]];
then
    ROLE='ResourceManager'
elif [[ "$HOST" =~ "JobHistory" ]];
then
    ROLE='JobHistory'
else
    echo -n "Invalid Role"
    exit 1
fi

desc="Hadoop ${ROLE} node daemon"

start() {
    echo -n $"Starting $desc: "
    case "$ROLE" in
        NameNode)
            sudo -u hdfs -i ${HADOOP_HOME}/sbin/start-dfs.sh
            RETVAL=$?
        ;;
        ResourceManager)
            sudo -u yarn -i ${HADOOP_HOME}/sbin/start-yarn.sh
            RETVAL=$?
        ;;
        JobHistory)
            sudo -u mapred -i ${HADOOP_HOME}/sbin/mr-jobhistory-daemon.sh start historyserver
            RETVAL=$?
        ;;
    esac
    return $RETVAL
}

stop() {
    echo -n $"Stopping $desc: "
    case "$ROLE" in
        NameNode)
            sudo -u hdfs -i ${HADOOP_HOME}/sbin/stop-dfs.sh
            RETVAL=$?
        ;;
        ResourceManager)
            sudo -u  yarn -i ${HADOOP_HOME}/sbin/stop-yarn.sh
            RETVAL=$?
        ;;
        JobHistory)
            sudo -u mapred -i ${HADOOP_HOME}/sbin/mr-jobhistory-daemon.sh stop historyserver
            RETVAL=$?
        ;;
    esac
    return $RETVAL
}

restart() {
    stop
    start
}

case "$1" in
    start)
        start
    ;;
    stop)
        stop
    ;;
    restart)
        restart
    ;;
    *)
        echo $"Usage: $0 {start|stop|restart}"
        exit 1
esac

exit $RETVAL
