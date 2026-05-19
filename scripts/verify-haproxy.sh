#!/bin/bash
#
# Script para verificar el estado de HAProxy
# Verifica frontends, backends, y health checks
#

echo "======================================"
echo "Verificando Estado de HAProxy"
echo "======================================"
echo ""

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar que HAProxy esté corriendo
echo "--- Estado del Contenedor ---"
if docker ps | grep -q haproxy; then
    echo -e "${GREEN}✓${NC} HAProxy está corriendo"
else
    echo -e "${RED}✗${NC} HAProxy NO está corriendo"
    exit 1
fi
echo ""

# Verificar frontends
echo "--- Frontends HAProxy ---"
echo "Frontend Escritura (mysql_write):"
if nc -zv localhost 3307 2>&1 | grep -q succeeded; then
    echo -e "  ${GREEN}✓${NC} Puerto 3307 abierto"
else
    echo -e "  ${RED}✗${NC} Puerto 3307 cerrado"
fi

echo ""
echo "Frontend Lectura (mysql_read):"
if nc -zv localhost 3308 2>&1 | grep -q succeeded; then
    echo -e "  ${GREEN}✓${NC} Puerto 3308 abierto"
else
    echo -e "  ${RED}✗${NC} Puerto 3308 cerrado"
fi

echo ""
echo "Dashboard Estadísticas:"
if nc -zv localhost 8080 2>&1 | grep -q succeeded; then
    echo -e "  ${GREEN}✓${NC} Puerto 8080 abierto"
    echo -e "  ${YELLOW}→${NC} Accede a: http://localhost:8080/stats"
    echo -e "  ${YELLOW}→${NC} Usuario: admin / Contraseña: admin123"
else
    echo -e "  ${RED}✗${NC} Puerto 8080 cerrado"
fi
echo ""

# Verificar backends mediante stats API
echo "--- Estado de Backends ---"
STATS_CSV=$(curl -s -u admin:admin123 "http://localhost:8080/stats;csv")

if [ -n "$STATS_CSV" ]; then
    echo "Backend: mysql_master_backend"
    MASTER_STATUS=$(echo "$STATS_CSV" | grep "mysql_master_backend,mysql-master" | cut -d',' -f18)
    if [ "$MASTER_STATUS" = "UP" ]; then
        echo -e "  ${GREEN}✓${NC} mysql-master: UP"
    else
        echo -e "  ${RED}✗${NC} mysql-master: $MASTER_STATUS"
    fi
    
    echo ""
    echo "Backend: mysql_slaves_backend"
    
    SLAVE1_STATUS=$(echo "$STATS_CSV" | grep "mysql_slaves_backend,mysql-slave1" | cut -d',' -f18)
    if [ "$SLAVE1_STATUS" = "UP" ]; then
        echo -e "  ${GREEN}✓${NC} mysql-slave1: UP"
    else
        echo -e "  ${RED}✗${NC} mysql-slave1: $SLAVE1_STATUS"
    fi
    
    SLAVE2_STATUS=$(echo "$STATS_CSV" | grep "mysql_slaves_backend,mysql-slave2" | cut -d',' -f18)
    if [ "$SLAVE2_STATUS" = "UP" ]; then
        echo -e "  ${GREEN}✓${NC} mysql-slave2: UP"
    else
        echo -e "  ${RED}✗${NC} mysql-slave2: $SLAVE2_STATUS"
    fi
else
    echo -e "${RED}✗${NC} No se pudo obtener información de backends"
fi

echo ""
echo "======================================"
echo "Verificación completada"
echo "======================================"