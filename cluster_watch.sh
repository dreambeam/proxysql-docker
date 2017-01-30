#!/bin/bash

ME=`basename $0`

# debug values
#DISCOVERY_SERVICE='10.50.41.11:4001'
#CLUSTER_NAME='dbcluster01'
# #############

# Get env variables
PXCADM_USER=${PXCADM_USER:-admin}
PXCADM_PASSWORD=${PXCADM_PASSWORD:-admin}
CLUSTER_NAME=${CLUSTER_NAME:-defaultcluster}
###

# Does not work on mac:
# ipaddr=$(hostname -i | awk ' { print $1 } ')

function mycnf_gen() {
    printf "[client]\nuser = %s\npassword = %s" "$PXCADM_USER" "$PXCADM_PASSWORD"
}

function update_proxysql() {
	mysql --defaults-file=<(mycnf_gen) -h 127.0.0.1 -P6032 -e "LOAD MYSQL SERVERS TO RUNTIME; SAVE MYSQL SERVERS TO DISK;"
}

function update_serverlist() {
	# Get current servers in proxysql
	IPS=`mysql --defaults-file=<(mycnf_gen) -h 127.0.0.1 -P6032 -B --disable-column-names -e 'SELECT hostname from mysql_servers' | sort`
	
	# Get cluster cluster members from discovery
	NEWIPS=`curl -s http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/$CLUSTER_NAME/ | jq -r '.node.nodes[]?.key' | awk -F'/' '{print $(NF)}' | sort`
	
	# Make a diff with folowing format: <prefix>ip =same -remove +add
	# ex: 
	# =10.0.0.1
	# -10.0.0.2
	# +10.0.0.3
	# Would keep 10.0.0.1, remove 10.0.0.2 and add 10.0.0.3 to the proxysql
	
	SDIFF=`diff --old-line-format='-%L' --new-line-format='+%L' --unchanged-line-format='=%L' <(for IP in $IPS; do echo $IP; done) <(for IP in $NEWIPS; do echo $IP; done)`
	
	for SERVER in $SDIFF
	do
		if [[ $SERVER == -* ]]
		then
			echo "$(date +'%Y-%m-%d %H:%M:%S,%3N') ${ME} REMOVE ${SERVER:1}"
			mysql --defaults-file=<(mycnf_gen) -h 127.0.0.1 -P6032 -e "DELETE FROM mysql_servers where hostname='${SERVER:1}';"
		elif [[ $SERVER == +* ]]
		then 
			echo "$(date +'%Y-%m-%d %H:%M:%S,%3N') ${ME} ADD ${SERVER:1}"
			mysql --defaults-file=<(mycnf_gen) -h 127.0.0.1 -P6032 -e "INSERT INTO mysql_servers (hostgroup_id, hostname, port, max_replication_lag) VALUES (0, '${SERVER:1}', 3306, 20);"
		fi
	done
}

echo "$(date +'%Y-%m-%d %H:%M:%S,%3N') ${ME} START"

while true; do
	sleep 5
	# Update the serverlist
	update_serverlist
	
	# Update users & servers in runtime
	update_proxysql
	
done

echo "$(date +'%Y-%m-%d %H:%M:%S,%3N') ${ME} STOP"
