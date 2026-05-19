#!/bin/bash
set -e

mkdir -p artifacts

USER=$(docker exec mysql-master printenv MYSQL_USER)
PASS=$(docker exec mysql-master printenv MYSQL_PASSWORD)
DB=$(docker exec mysql-master printenv MYSQL_DATABASE)
NETWORK=$(docker network ls --format '{{.Name}}' | grep 'mysql-network' | head -n1)

echo "======================================"
echo "Sysbench Benchmarks"
echo "DB=$DB USER=$USER NETWORK=$NETWORK"
echo "======================================"

echo ""
echo "Preparando tablas de prueba en el MASTER por puerto 3307..."
docker run --rm --network "$NETWORK" severalnines/sysbench \
  sysbench /usr/share/sysbench/oltp_common.lua \
  --mysql-host=haproxy \
  --mysql-port=3307 \
  --mysql-user="$USER" \
  --mysql-password="$PASS" \
  --mysql-db="$DB" \
  --tables=4 \
  --table-size=5000 \
  prepare

echo ""
echo "======================================"
echo "Benchmark READ-ONLY -> HAProxy puerto 3308"
echo "8 hilos durante 60 segundos"
echo "======================================"
docker run --rm --network "$NETWORK" severalnines/sysbench \
  sysbench /usr/share/sysbench/oltp_read_only.lua \
  --mysql-host=haproxy \
  --mysql-port=3308 \
  --mysql-user="$USER" \
  --mysql-password="$PASS" \
  --mysql-db="$DB" \
  --tables=4 \
  --table-size=5000 \
  --threads=8 \
  --time=60 \
  --report-interval=10 \
  run | tee artifacts/sysbench-read-only.log

echo ""
echo "======================================"
echo "Benchmark READ/WRITE -> HAProxy puerto 3307"
echo "8 hilos durante 60 segundos"
echo "======================================"
docker run --rm --network "$NETWORK" severalnines/sysbench \
  sysbench /usr/share/sysbench/oltp_read_write.lua \
  --mysql-host=haproxy \
  --mysql-port=3307 \
  --mysql-user="$USER" \
  --mysql-password="$PASS" \
  --mysql-db="$DB" \
  --tables=4 \
  --table-size=5000 \
  --threads=8 \
  --time=60 \
  --report-interval=10 \
  run | tee artifacts/sysbench-read-write.log

echo ""
echo "======================================"
echo "Limpiando tablas Sysbench..."
echo "======================================"
docker run --rm --network "$NETWORK" severalnines/sysbench \
  sysbench /usr/share/sysbench/oltp_common.lua \
  --mysql-host=haproxy \
  --mysql-port=3307 \
  --mysql-user="$USER" \
  --mysql-password="$PASS" \
  --mysql-db="$DB" \
  --tables=4 \
  cleanup

echo ""
echo "Resultados guardados en:"
echo "artifacts/sysbench-read-only.log"
echo "artifacts/sysbench-read-write.log"

echo ""
echo "Resumen TPS:"
echo "READ-ONLY:"
grep "transactions:" artifacts/sysbench-read-only.log || true
echo "READ/WRITE:"
grep "transactions:" artifacts/sysbench-read-write.log || true
