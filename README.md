'''
ProxySQL ENV configuration:

CLUSTER_NAME*	string:
<name of cluster to monitor>
default: cluster01

DISCOVERY_SERVICE*	string: 
<ip:port>

DISCOVERY_SLEEP		int:
<time in seconds>
default: 15
Time to sleep between checking servers in ProxySQL and ETCD backend.

ADMIN_USER		string:
<username>
default: admin

ADMIN_PASS		string:
<password>
default: admin

ADMIN_PORT		int:
<port>
defaut: 6032

MYSQL_BOOTSTRAP		true/false:
if set to 'true' the entrypoint script for ProxySQL will create a superuser on each mysql server.

The following ENV variables are only usable if MYSQL_BOOTSTRAP is set to 'true'

MYSQL_PROXY_USER	string:
<username>
mysql superuser name

MYSQL_PROXY_PASS	string:
<password>
mysql superuser password

MYSQL_ROOT_PASSWORD string:
<password>
root password on mysql cluster nodes
'''
