CLUSTER_NAME=${CLUSTER_NAME:-cluster01}
ETCD_HOST=${ETCD_HOST:-10.50.41.11:4001}

docker run --rm -t --name=${CLUSTER_NAME}_proxysql \
	-p 3306:3306 -p 6032:6032 \
	-e CLUSTER_NAME=$CLUSTER_NAME \
	-e MYSQL_BOOTSTRAP="true" \
	-e DISCOVERY_SERVICE=$ETCD_HOST \
	-e DISCOVERY_SLEEP='5' \
	-e ADMIN_USER="admin" \
	-e ADMIN_PASS="qazXSW21!!" \
	-e MYSQL_ROOT_PASSWORD="str0nkpassword!" \
	-e MYSQL_PROXY_USER="access" \
	-e MYSQL_PROXY_PASS="s3cret" \
	proxysql

