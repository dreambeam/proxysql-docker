#!/bin/bash

ME=`basename $0`

if [ -z "$CLUSTER_NAME" ]; then
        echo >&2 '$(date +'%Y-%m-%d %H:%M:%S,%3N') ${ME} ERROR:  You need to specify CLUSTER_NAME'
        exit 1
fi

# Get env variables
CLUSTER_NAME=${CLUSTER_NAME:-cluster01}
###

function mycnf_gen() {
    printf "[client]\nuser = %s\npassword = %s" "${ADMIN_USER:-admin}" "${ADMIN_PASS:-admin}"
}

function update_proxysql() {
	mysql --defaults-file=<(mycnf_gen) -h 127.0.0.1 -P${ADMIN_PORT:-6032} -e "LOAD MYSQL SERVERS TO RUNTIME; SAVE MYSQL SERVERS TO DISK;"
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
			mysql --defaults-file=<(mycnf_gen) -h 127.0.0.1 -P${ADMIN_PORT:-6032} -e "DELETE FROM mysql_servers where hostname='${SERVER:1}';"
		elif [[ $SERVER == +* ]]
		then 
			echo "$(date +'%Y-%m-%d %H:%M:%S,%3N') ${ME} ADD ${SERVER:1}"
			mysql --defaults-file=<(mycnf_gen) -h 127.0.0.1 -P${ADMIN_PORT:-6032} -e "INSERT INTO mysql_servers (hostgroup_id, hostname, port, max_replication_lag) VALUES (0, '${SERVER:1}', 3306, 20);"
		fi
	done
}

function setup_monitoring() {
    # Best practice is to have a not privileged user here with only grant usage.
	mysql -h 127.0.0.1 -P${ADMIN_PORT} -u${ADMIN_USER} -p${ADMIN_PASS} -e "UPDATE global_variables SET variable_value='${ADMIN_USER}' WHERE variable_name='mysql-monitor_username';"
	mysql -h 127.0.0.1 -P${ADMIN_PORT} -u${ADMIN_USER} -p${ADMIN_PASS} -e "UPDATE global_variables SET variable_value='${ADMIN_PASS}' WHERE variable_name='mysql-monitor_password';"
	mysql -h 127.0.0.1 -P${ADMIN_PORT} -u${ADMIN_USER} -p${ADMIN_PASS} -e "LOAD MYSQL VARIABLES TO RUNTIME; SAVE MYSQL VARIABLES TO DISK;"
}


echo "$(date +'%Y-%m-%d %H:%M:%S,%3N') ${ME} START"

if [ $MYSQL_BOOTSTRAP == "true" ]; then
	echo "$(date +'%Y-%m-%d %H:%M:%S,%3N') ${ME} Creating mysql superuser"
	
	sleep 10 # let proxysql start gracefully before continuing

	for i in $(curl http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/$CLUSTER_NAME/ | jq -r '.node.nodes[]?.key' | awk -F'/' '{print $(NF)}')
	do
	        mysql -h $i -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT ALL ON *.* TO '${MYSQL_PROXY_USER}'@'%' IDENTIFIED BY '${MYSQL_PROXY_PASS}'"
	        mysql -h $i -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT GRANT OPTION ON *.* TO '${MYSQL_PROXY_USER}'@'%';"
	 done
	
	mysql -h 127.0.0.1 -P${ADMIN_PORT} -u${ADMIN_USER} -p${ADMIN_PASS} -e "INSERT INTO mysql_users (username, password, active, default_hostgroup, max_connections) VALUES ('$MYSQL_PROXY_USER', '$MYSQL_PROXY_PASS', 1, 0, 200);"
	mysql -h 127.0.0.1 -P${ADMIN_PORT} -u${ADMIN_USER} -p${ADMIN_PASS} -e "LOAD MYSQL USERS TO RUNTIME; SAVE MYSQL USERS TO DISK;"

fi


while true; do
	sleep ${DISCOVERY_SLEEP:-15}

	# Update the serverlist
	update_serverlist
	
	# Update users & servers in runtime
	update_proxysql
	
done

echo "$(date +'%Y-%m-%d %H:%M:%S,%3N') ${ME} STOP"
