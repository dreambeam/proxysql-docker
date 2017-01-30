CLUSTER_NAME=${CLUSTER_NAME:-cluster01}
ETCD_HOST=${ETCD_HOST:-10.50.41.11:4001}

docker run --rm --name=${CLUSTER_NAME}_proxysql \
	-p 3306:3306 -p 6032:6032 \
	-e CLUSTER_NAME=$CLUSTER_NAME \
	-e MYSQL_BOOTSTRAP=false \
	-e DISCOVERY_SERVICE=$ETCD_HOST \
	-e MYSQL_ROOT_PASSWORD="str0nkpassword!" \
	-e MYSQL_PROXY_USER="admin" \
	-e MYSQL_PROXY_PASS="s3cret" \
	proxysql

