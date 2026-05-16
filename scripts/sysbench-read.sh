#!/bin/bash
source .env

docker exec -it sysbench sysbench oltp_read_only \
  --db-driver=mysql \
  --mysql-host=haproxy \
  --mysql-port=3308 \
  --mysql-user=${MYSQL_USER} \
  --mysql-password=${MYSQL_PASSWORD} \
  --mysql-db=${MYSQL_DATABASE} \
  --tables=4 \
  --table-size=10000 \
  --threads=8 \
  --time=60 \
  --report-interval=10 \
  run