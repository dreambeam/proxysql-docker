ProxySQL Docker image 
=====================

[The ProxySQL image](https://hub.docker.com/r/perconalab/proxysql/)
provides an integration with Percona XtraDB Cluster and discovery service.

This image is customized with an automated clusterwatch/registration service, thus fits deployments on `DC/OS`.

Usage
-----

You can start proxysql image by:
```
$ docker run -d -p 3306:3306 -p 6032:6032 --net=$NETWORK_NAME --name=${CLUSTER_NAME}_proxysql \
        -e CLUSTER_NAME=$CLUSTER_NAME \
        -e MYSQL_BOOTSTRAP=true \
        -e DISCOVERY_SERVICE=$ETCD_HOST \
        -e MYSQL_ROOT_PASSWORD=root \
        -e MYSQL_PROXY_USER=proxyuser \
        -e MYSQL_PROXY_PASS=s3cret \
        dreambeam/proxy-sql
```

where `MYSQL_ROOT_PASSWORD` is the root password for the MySQL nodes. The password is needed to register the proxy user.
The user `MYSQL_PROXY_USER` with password `MYSQL_PROXY_PASSWORD` will be registered on all Percona XtraDB Cluster nodes.


Running ProxySQL with Percona XtraDB
------------------------------------
`WIP`

**Environment variables configuration**

Do not miss out the following environment variables:
1. CLUSTER_NAME:
	- String
	- Default: cluster01
2. DISCOVERY_SERVICE:
	- String
	- `ip:port`
3. DISCOVERY_SLEEP:
	- Int: Time to sleep in seconds between checking servers in ProxySQL and ETCD backend
	- Default: 15
4. ADMIN_USER:
	- String `username`
	- Default: admin
5. ADMIN_PASS:
	- String `password`
	- Default: admin
6. ADMIN_PORT:
	- Int `port`
	- Default: 6032
7. MYSQL_BOOTSTRAP:
	- `true/false`
	- If set to `true` the entrypoint script for ProxySQL will create a superuser on each mysql server

**The following ENV variables are only usable if MYSQL_BOOTSTRAP is set to 'true'**
1. MYSQL_PROXY_USER:
	- String `username`
	- mysql superuser name
2. MYSQL_PROXY_PASS:
	- String `password`
	- mysql superuser password
3. MYSQL_ROOT_PASSWORD:
	- String `password`
	- Root password on mysql cluster nodes

Acknowlegdment
--------------
[proxysql-docker](https://github.com/pasientskyhosting/proxysql-docker)
