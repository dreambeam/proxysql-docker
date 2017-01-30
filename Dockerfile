FROM centos:7
MAINTAINER Joakim Karlsson <jk@patientsky.com>

RUN yum install -y epel-release

RUN yum -y update && yum clean all

RUN yum install -y https://github.com/sysown/proxysql/releases/download/v1.3.3/proxysql-1.3.3-1-centos7.x86_64.rpm

RUN rpmkeys --import https://www.percona.com/downloads/RPM-GPG-KEY-percona
RUN yum install -y http://www.percona.com/downloads/percona-release/redhat/0.1-3/percona-release-0.1-3.noarch.rpm
RUN yum install -y Percona-Server-client-56

RUN yum -y install supervisor && yum clean all


ADD proxysql.tmpl /etc/proxysql.tmpl
COPY proxysql-entry.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh


COPY jq /usr/bin/jq
RUN chmod a+x /usr/bin/jq

# COPY add_cluster_nodes.sh /usr/bin/add_cluster_nodes.sh
# RUN chmod a+x /usr/bin/add_cluster_nodes.sh

COPY clusterwatch.sh /clusterwatch.sh
RUN chmod a+x /clusterwatch.sh

ADD supervisord.conf /etc/supervisord.conf

VOLUME /var/lib/proxysql

EXPOSE 3306 6032
ONBUILD RUN yum update -y

ENTRYPOINT ["/usr/bin/supervisord"]
CMD ["-c", "/etc/supervisord.conf"]

