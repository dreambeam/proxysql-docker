#!/bin/bash

ipaddr=$(hostname -i | awk ' { print $1 } ')

for i in $(curl http://$DISCOVERY_SERVICE/v2/keys/pxc-cluster/$CLUSTER_NAME/ | jq -r '.node.nodes[]?.key' | awk -F'/' '{print $(NF)}')
do
	echo $i 
        mysql -h 127.0.0.1 -P6032 -uadmin -padmin -e "INSERT INTO mysql_servers (hostgroup_id, hostname, port, max_replication_lag) VALUES (0, '$i', 3306, 20);"
 done

mysql -h 127.0.0.1 -P6032 -uadmin -padmin -e "LOAD MYSQL SERVERS TO RUNTIME; SAVE MYSQL SERVERS TO DISK;"
