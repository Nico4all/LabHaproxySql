#!/bin/bash
source .env

docker exec -it sysbench sysbench oltp_read_write \
  --db-driver=mysql \
  --mysql-host=haproxy \
  --mysql-port=3307 \
  --mysql-user=${MYSQL_USER} \
  --mysql-password=${MYSQL_PASSWORD} \
  --mysql-db=${MYSQL_DATABASE} \
  --tables=4 \
  --table-size=10000 \
  prepare