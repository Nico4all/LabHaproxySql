FROM mysql:8.0-bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends xinetd procps netcat-openbsd && \
    rm -rf /var/lib/apt/lists/*

COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

COPY mysqlchk.xinetd /etc/xinetd.d/mysqlchk
RUN chmod 644 /etc/xinetd.d/mysqlchk

COPY docker-entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

COPY mysql-master.cnf /etc/mysql/conf.d/mysql-master.cnf
COPY mysql-slave.cnf /etc/mysql/conf.d/mysql-slave.cnf

RUN chmod 644 /etc/mysql/conf.d/mysql-master.cnf && \
    chmod 644 /etc/mysql/conf.d/mysql-slave.cnf

ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
CMD ["mysqld"]