#!/bin/bash
if [ $MYSQL_BOOTSTRAP == "true" ]; then

	for i in $(curl http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/$CLUSTER_NAME/ | jq -r '.node.nodes[]?.key' | awk -F'/' '{print $(NF)}')
	do
		echo $i 
	        mysql -h $i -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT ALL ON *.* TO '${MYSQL_PROXY_USER}'@'%' IDENTIFIED BY '${MYSQL_PROXY_PASSWORD}'"
	        mysql -h $i -uroot -p${MYSQL_ROOT_PASSWORD} -e "GRANT GRANT OPTION ON *.* TO '${MYSQL_PROXY_USER}'@'%';"
	 done
	
	mysql -h 127.0.0.1 -P6032 -uadmin -padmin -e "INSERT INTO mysql_users (username, password, active, default_hostgroup, max_connections) VALUES ('$MYSQL_PROXY_USER', '$MYSQL_PROXY_PASS', 1, 0, 200);"
	mysql -h 127.0.0.1 -P6032 -uadmin -padmin -e "LOAD MYSQL USERS TO RUNTIME; SAVE MYSQL USERS TO DISK;"

fi