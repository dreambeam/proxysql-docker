#!/bin/bash

ME=`basename $0`

if [ -z "$CLUSTER_NAME" ]; then
        echo >&2 '$(date +'%Y-%m-%d %H:%M:%S,%3N') ${ME} ERROR:  You need to specify CLUSTER_NAME'
        exit 1
fi

# Get env variables
ADMIN_PORT=${ADMIN_PORT:-6032}
ADMIN_USER=${ADMIN_USER:-admin}
ADMIN_PASS=${ADMIN_PASS:-admin}
CLUSTER_NAME=${CLUSTER_NAME:-cluster01}
DISCOVERY_SLEEP=${DISCOVERY_SLEEP:-15}
###

function mycnf_gen() {
    printf "[client]\nuser = %s\npassword = %s\nport = %s\nhost = %s" "${ADMIN_USER}" "${ADMIN_PASS}" "${ADMIN_PORT}" "127.0.0.1"
}

function mycnf_rootgen() {
    printf "[client]\nuser = %s\npassword = %s" "root" "${MYSQL_ROOT_PASSWORD}"
}

function update_serverlist() {
	# Get current servers in proxysql
	IPS=`mysql --defaults-file=<(mycnf_gen) -B --disable-column-names -e 'SELECT hostname from mysql_servers' | sort`
	
	# Get cluster cluster members from discovery
	NEWIPS=`curl -s http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/$CLUSTER_NAME/ | jq -r '.node.nodes[]?.key' | awk -F'/' '{print $(NF)}' | sort`
	
	# Make a diff with folowing format: <prefix>ip =same -remove +add
	# ex: 
	# =10.0.0.1
	# -10.0.0.2
	# +10.0.0.3
	# Would keep 10.0.0.1, remove 10.0.0.2 and add 10.0.0.3 to the proxysql
	
	SDIFF=`diff --old-line-format='-%L' --new-line-format='+%L' --unchanged-line-format='=%L' <(for IP in $IPS; do echo $IP; done) <(for IP in $NEWIPS; do echo $IP; done)`
	
	CHANGES=false
	for SERVER in $SDIFF
	do
		if [[ $SERVER == -* ]]
		then
			echo "$(date +'%Y-%m-%d %H:%M:%S,%3N') ${ME} REMOVE ${SERVER:1}"
			mysql --defaults-file=<(mycnf_gen) -e "DELETE FROM mysql_servers where hostname='${SERVER:1}';"
			CHANGES=true
		elif [[ $SERVER == +* ]]
		then 
			echo "$(date +'%Y-%m-%d %H:%M:%S,%3N') ${ME} ADD ${SERVER:1}"
			mysql --defaults-file=<(mycnf_gen) -e "INSERT INTO mysql_servers (hostgroup_id, hostname, port, max_replication_lag) VALUES (0, '${SERVER:1}', 3306, 20);"
			CHANGES=true
		fi
	done
	if [[ ${CHANGES} == true ]]
	then
		mysql --defaults-file=<(mycnf_gen) -e "LOAD MYSQL SERVERS TO RUNTIME; SAVE MYSQL SERVERS TO DISK;"
	fi
}

function setup_monitoring() {
    # Best practice is to have a not privileged user here with only grant usage.
    sleep 15 # wait for proxysql to start gracefully
    echo "$(date +'%Y-%m-%d %H:%M:%S,%3N') ${ME} Setup monitor user in proxysql"
	mysql --defaults-file=<(mycnf_gen) -e "UPDATE global_variables SET variable_value='${ADMIN_USER}' WHERE variable_name='mysql-monitor_username';"
	mysql --defaults-file=<(mycnf_gen) -e "UPDATE global_variables SET variable_value='${ADMIN_PASS}' WHERE variable_name='mysql-monitor_password';"
	mysql --defaults-file=<(mycnf_gen) -e "LOAD MYSQL VARIABLES TO RUNTIME; SAVE MYSQL VARIABLES TO DISK;"
}


echo "$(date +'%Y-%m-%d %H:%M:%S,%3N') ${ME} START"

if [[ ${MYSQL_BOOTSTRAP} == true ]]; then
	echo "$(date +'%Y-%m-%d %H:%M:%S,%3N') ${ME} Creating mysql superuser"
	
	sleep 10 # let proxysql start gracefully before continuing

	for SERVER in $(curl -s http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/$CLUSTER_NAME/ | jq -r '.node.nodes[]?.key' | awk -F'/' '{print $(NF)}')
	do
	        mysql --defaults-file=<(mycnf_rootgen) -h${SERVER} -e "GRANT ALL ON *.* TO '${MYSQL_PROXY_USER}'@'%' IDENTIFIED BY '${MYSQL_PROXY_PASS}'"
	        mysql --defaults-file=<(mycnf_rootgen) -h${SERVER} -e "GRANT GRANT OPTION ON *.* TO '${MYSQL_PROXY_USER}'@'%';"
	 done
	
	mysql --defaults-file=<(mycnf_gen) -e "INSERT INTO mysql_users (username, password, active, default_hostgroup, max_connections) VALUES ('${MYSQL_PROXY_USER}', '${MYSQL_PROXY_PASS}', 1, 0, 200);"
	mysql --defaults-file=<(mycnf_gen) -e "LOAD MYSQL USERS TO RUNTIME; SAVE MYSQL USERS TO DISK;"

fi

setup_monitoring

while true; do
	echo "$(date +'%Y-%m-%d %H:%M:%S,%3N') ${ME} PiNG"
	sleep ${DISCOVERY_SLEEP}

	# Update the serverlist
	update_serverlist
	
done

echo "$(date +'%Y-%m-%d %H:%M:%S,%3N') ${ME} STOP"
