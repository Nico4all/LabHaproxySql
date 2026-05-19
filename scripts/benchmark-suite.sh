#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_DIR="/vagrant/benchmarks/reports"
RESULTS_FILE="${REPORT_DIR}/benchmark_${TIMESTAMP}.txt"

mkdir -p ${REPORT_DIR}

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  MySQL + HAProxy Performance Benchmark${NC}"
echo -e "${BLUE}  $(date)${NC}"
echo -e "${BLUE}============================================${NC}"

# Configuración
MYSQL_HOST="192.168.56.10"
MYSQL_USER="root"
MYSQL_PASS="rootpass123"
MYSQL_DB="sbtest"
THREADS=(1 4 8 16)  # Diferentes niveles de concurrencia

# Función para ejecutar test
run_test() {
    local TEST_NAME=$1
    local PORT=$2
    local LUA_SCRIPT=$3
    local THREADS=$4
    
    echo -e "\n${YELLOW}[TEST] ${TEST_NAME} - ${THREADS} threads${NC}" | tee -a ${RESULTS_FILE}
    
    sysbench ${LUA_SCRIPT} \
        --mysql-host=${MYSQL_HOST} \
        --mysql-port=${PORT} \
        --mysql-user=${MYSQL_USER} \
        --mysql-password=${MYSQL_PASS} \
        --mysql-db=${MYSQL_DB} \
        --tables=10 \
        --table-size=100000 \
        --threads=${THREADS} \
        --time=60 \
        --report-interval=10 \
        run | tee -a ${RESULTS_FILE}
    
    sleep 5
}

# Preparar base de datos
echo -e "\n${GREEN}[1/5] Preparando base de datos...${NC}"
mysql -h${MYSQL_HOST} -P3307 -u${MYSQL_USER} -p${MYSQL_PASS} -e "DROP DATABASE IF EXISTS ${MYSQL_DB}; CREATE DATABASE ${MYSQL_DB};"

sysbench /usr/share/sysbench/oltp_read_write.lua \
    --mysql-host=${MYSQL_HOST} \
    --mysql-port=3307 \
    --mysql-user=${MYSQL_USER} \
    --mysql-password=${MYSQL_PASS} \
    --mysql-db=${MYSQL_DB} \
    --tables=10 \
    --table-size=100000 \
    prepare > /dev/null 2>&1

# Tests
echo -e "\n${GREEN}[2/5] Read-Only Tests (Puerto 3308 - Esclavos)${NC}"
for THREAD_COUNT in "${THREADS[@]}"; do
    run_test "READ-ONLY" 3308 "/usr/share/sysbench/oltp_read_only.lua" ${THREAD_COUNT}
done

echo -e "\n${GREEN}[3/5] Read-Write Tests (Puerto 3307 - Maestro)${NC}"
for THREAD_COUNT in "${THREADS[@]}"; do
    run_test "READ-WRITE" 3307 "/usr/share/sysbench/oltp_read_write.lua" ${THREAD_COUNT}
done

echo -e "\n${GREEN}[4/5] Write-Only Tests (Puerto 3307 - Maestro)${NC}"
for THREAD_COUNT in "${THREADS[@]}"; do
    run_test "WRITE-ONLY" 3307 "/usr/share/sysbench/oltp_write_only.lua" ${THREAD_COUNT}
done

# Generar resumen
echo -e "\n${GREEN}[5/5] Generando reporte resumen...${NC}"
python3 /vagrant/scripts/generate-benchmark-report.py ${RESULTS_FILE}

echo -e "\n${BLUE}============================================${NC}"
echo -e "${GREEN}✓ Benchmark completado${NC}"
echo -e "Resultados guardados en: ${RESULTS_FILE}"
echo -e "Reporte HTML: ${REPORT_DIR}/benchmark_${TIMESTAMP}.html"
echo -e "${BLUE}============================================${NC}"