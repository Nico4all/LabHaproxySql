#!/bin/bash
#
# Script para verificar los health checks HTTP de los nodos MySQL
#

source .env

echo "======================================"
echo "Verificando Health Checks HTTP"
echo "======================================"
echo ""

# Función para verificar health check
check_health() {
    local name=$1
    local port=$2
    
    echo "--- $name (Puerto $port) ---"
    
    response=$(curl -s -w "\nHTTP_CODE:%{http_code}" http://localhost:$port 2>/dev/null)
    http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    body=$(echo "$response" | grep -v "HTTP_CODE:")
    
    if [ "$http_code" = "200" ]; then
        echo "✓ Health Check: OK (HTTP $http_code)"
        echo "Respuesta: $body"
    elif [ "$http_code" = "503" ]; then
        echo "✗ Health Check: FAILED (HTTP $http_code)"
        echo "Respuesta: $body"
    else
        echo "✗ Health Check: ERROR (HTTP $http_code o sin respuesta)"
    fi
    
    echo ""
}

# Verificar health checks de cada nodo
check_health "MySQL Master" "${MASTER_HEALTH_PORT}"
check_health "MySQL Slave 1" "${SLAVE1_HEALTH_PORT}"
check_health "MySQL Slave 2" "${SLAVE2_HEALTH_PORT}"

echo "======================================"
echo "Verificación completada"
echo "======================================"