#!/bin/bash
#
# Quick Start Script - Parte 2: MySQL + HAProxy
# Levanta todo el stack y verifica que funcione
#

set -e  # Salir si cualquier comando falla

MYSQL_ROOT_PASSWORD="rootpass123"

echo "=========================================="
echo "  MySQL + HAProxy Load Balancer"
echo "  Quick Start - Parte 2"
echo "=========================================="
echo ""

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#
# Paso 1: Limpiar estado anterior (opcional)
#
echo -e "${BLUE}[1/8]${NC} Verificando estado anterior..."
if docker-compose ps | grep -q Up; then
    echo -e "${YELLOW}→${NC} Contenedores existentes detectados"
    read -p "¿Deseas limpiar y empezar desde cero? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}→${NC} Deteniendo y eliminando contenedores..."
        docker-compose down -v
        echo -e "${GREEN}✓${NC} Limpieza completada"
    else
        echo -e "${YELLOW}→${NC} Continuando con contenedores existentes"
    fi
else
    echo -e "${GREEN}✓${NC} No hay contenedores previos"
fi
echo ""

#
# Paso 2: Construir imágenes
#
echo -e "${BLUE}[2/8]${NC} Construyendo imágenes Docker..."
docker-compose build --no-cache
echo -e "${GREEN}✓${NC} Imágenes construidas"
echo ""

#
# Paso 3: Levantar servicios
#
echo -e "${BLUE}[3/8]${NC} Levantando servicios..."
docker-compose up -d
echo -e "${GREEN}✓${NC} Servicios iniciados"
echo ""

#
# Paso 4: Esperar inicialización
#
echo -e "${BLUE}[4/8]${NC} Esperando inicialización de MySQL (90 segundos)..."
for i in {1..9}; do
    echo -n "."
    sleep 10
done
echo ""
echo -e "${GREEN}✓${NC} Espera completada"
echo ""

#
# Paso 5: Verificar contenedores
#
echo -e "${BLUE}[5/8]${NC} Verificando estado de contenedores..."
docker-compose ps
echo ""

#
# Paso 6: Arreglar configuración inicial
#
echo -e "${BLUE}[6/8]${NC} Configurando maestro y esclavos..."

# Arreglar read_only del maestro
echo -e "${YELLOW}→${NC} Configurando read_only=OFF en el maestro..."
docker exec -it mysql-master mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "
SET GLOBAL read_only = OFF;
SET GLOBAL super_read_only = OFF;
" 2>/dev/null
echo -e "${GREEN}✓${NC} Maestro configurado"

# Obtener UUID del maestro
MASTER_UUID=$(docker exec mysql-master mysql -uroot -p${MYSQL_ROOT_PASSWORD} -s -N -e "SELECT @@server_uuid" 2>/dev/null | tr -d '\r' | tr -d ' ')
echo -e "${YELLOW}→${NC} UUID del maestro: ${MASTER_UUID}"

# Arreglar replicación en esclavos (saltar transacción problemática)
echo -e "${YELLOW}→${NC} Configurando replicación en esclavos..."

docker exec -i mysql-slave1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} << EOF 2>/dev/null
STOP REPLICA;
SET GTID_NEXT='${MASTER_UUID}:7';
BEGIN; COMMIT;
SET GTID_NEXT='AUTOMATIC';
START REPLICA;
EOF

docker exec -i mysql-slave2 mysql -uroot -p${MYSQL_ROOT_PASSWORD} << EOF 2>/dev/null
STOP REPLICA;
SET GTID_NEXT='${MASTER_UUID}:7';
BEGIN; COMMIT;
SET GTID_NEXT='AUTOMATIC';
START REPLICA;
EOF

echo -e "${GREEN}✓${NC} Replicación configurada"
echo ""

#
# Paso 7: Verificar todo
#
echo -e "${BLUE}[7/8]${NC} Verificando configuración..."
echo ""

echo -e "${YELLOW}→${NC} Verificando replicación MySQL..."
./scripts/verify-replication.sh
echo ""

echo -e "${YELLOW}→${NC} Verificando health checks..."
./scripts/verify-healthchecks.sh
echo ""

echo -e "${YELLOW}→${NC} Verificando HAProxy..."
./scripts/verify-haproxy.sh
echo ""

#
# Paso 8: Probar balanceo de carga
#
echo -e "${BLUE}[8/8]${NC} Probando balanceo de carga..."
echo ""
./scripts/test-haproxy-balancing.sh
echo ""

#
# Resumen final
#
echo ""
echo "=========================================="
echo "  ✓ Instalación Completada"
echo "=========================================="
echo ""
echo -e "${GREEN}Servicios Disponibles:${NC}"
echo -e "  • MySQL Escritura (via HAProxy): localhost:3307"
echo -e "  • MySQL Lectura (via HAProxy):   localhost:3308"
echo -e "  • MySQL Master (directo):        localhost:3306"
echo -e "  • MySQL Slave 1 (directo):       localhost:3316"
echo -e "  • MySQL Slave 2 (directo):       localhost:3326"
echo -e "  • HAProxy Dashboard:             http://localhost:8080/stats"
echo -e "    Usuario: admin / Contraseña: admin123"
echo ""
echo -e "${YELLOW}Comandos Útiles:${NC}"
echo -e "  • Ver logs:              docker-compose logs -f"
echo -e "  • Ver estado:            docker-compose ps"
echo -e "  • Verificar replicación: ./scripts/verify-replication.sh"
echo -e "  • Verificar HAProxy:     ./scripts/verify-haproxy.sh"
echo -e "  • Probar balanceo:       ./scripts/test-haproxy-balancing.sh"
echo -e "  • Detener todo:          docker-compose down"
echo ""
echo -e "${GREEN}¡Listo para usar!${NC}"
echo ""