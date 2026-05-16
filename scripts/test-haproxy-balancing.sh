#!/bin/bash
#
# Script para probar el balanceo de carga de HAProxy
# Demuestra que:
# - Escrituras van al maestro (puerto 3307)
# - Lecturas se balancean entre esclavos (puerto 3308)
#

MYSQL_ROOT_PASSWORD="rootpass123"

echo "======================================"
echo "Prueba de Balanceo de Carga HAProxy"
echo "======================================"
echo ""

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#
# Parte 1: Probar escritura a través de HAProxy (puerto 3307 → maestro)
#
echo -e "${BLUE}=== Prueba 1: Escritura a través de HAProxy (puerto 3307) ===${NC}"
echo ""
echo "1. Creando tabla de prueba a través del BALANCEADOR (puerto 3307)..."

mysql -h127.0.0.1 -P3307 -uroot -p${MYSQL_ROOT_PASSWORD} -e "
DROP TABLE IF EXISTS testdb.haproxy_test;
CREATE TABLE testdb.haproxy_test (
    id INT AUTO_INCREMENT PRIMARY KEY,
    message VARCHAR(255),
    server_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Tabla creada exitosamente"
else
    echo -e "${RED}✗${NC} Error al crear tabla"
    exit 1
fi

echo ""
echo "2. Insertando 5 registros a través del BALANCEADOR (puerto 3307)..."

for i in {1..5}; do
    mysql -h127.0.0.1 -P3307 -uroot -p${MYSQL_ROOT_PASSWORD} -e "
    INSERT INTO testdb.haproxy_test (message, server_id) 
    VALUES ('Mensaje #$i insertado via HAProxy', @@server_id);
    " 2>/dev/null
    echo -e "   ${GREEN}✓${NC} Registro #$i insertado"
done

echo ""
echo "3. Esperando replicación (3 segundos)..."
sleep 3

echo ""
echo "4. Verificando datos en el MAESTRO (directo, puerto 3306)..."
MASTER_COUNT=$(mysql -h127.0.0.1 -P3306 -uroot -p${MYSQL_ROOT_PASSWORD} -s -N -e "
SELECT COUNT(*) FROM testdb.haproxy_test;
" 2>/dev/null)

echo -e "   ${YELLOW}→${NC} Total de registros en maestro: ${MASTER_COUNT}"

echo ""
echo "5. Verificando replicación en ESCLAVO 1 (directo, puerto 3316)..."
SLAVE1_COUNT=$(mysql -h127.0.0.1 -P3316 -uroot -p${MYSQL_ROOT_PASSWORD} -s -N -e "
SELECT COUNT(*) FROM testdb.haproxy_test;
" 2>/dev/null)

echo -e "   ${YELLOW}→${NC} Total de registros en esclavo 1: ${SLAVE1_COUNT}"

echo ""
echo "6. Verificando replicación en ESCLAVO 2 (directo, puerto 3326)..."
SLAVE2_COUNT=$(mysql -h127.0.0.1 -P3326 -uroot -p${MYSQL_ROOT_PASSWORD} -s -N -e "
SELECT COUNT(*) FROM testdb.haproxy_test;
" 2>/dev/null)

echo -e "   ${YELLOW}→${NC} Total de registros en esclavo 2: ${SLAVE2_COUNT}"

if [ "$MASTER_COUNT" -eq 5 ] && [ "$SLAVE1_COUNT" -eq 5 ] && [ "$SLAVE2_COUNT" -eq 5 ]; then
    echo ""
    echo -e "${GREEN}✓${NC} Replicación exitosa: todos los nodos tienen 5 registros"
else
    echo ""
    echo -e "${RED}✗${NC} Error de replicación"
fi

#
# Parte 2: Probar lectura balanceada a través de HAProxy (puerto 3308 → esclavos)
#
echo ""
echo ""
echo -e "${BLUE}=== Prueba 2: Lectura Balanceada a través de HAProxy (puerto 3308) ===${NC}"
echo ""
echo "Ejecutando 10 lecturas a través del balanceador (puerto 3308)..."
echo "Esperamos que se distribuyan entre slave1 (server_id=2) y slave2 (server_id=3)"
echo ""

# Contador de lecturas por servidor
declare -A SERVER_COUNTS

for i in {1..10}; do
    SERVER_ID=$(mysql -h127.0.0.1 -P3308 -uroot -p${MYSQL_ROOT_PASSWORD} -s -N -e "
    SELECT @@server_id;
    " 2>/dev/null)
    
    if [ -n "$SERVER_ID" ]; then
        # Incrementar contador
        ((SERVER_COUNTS[$SERVER_ID]++))
        
        # Determinar nombre del servidor
        if [ "$SERVER_ID" = "2" ]; then
            SERVER_NAME="slave1"
        elif [ "$SERVER_ID" = "3" ]; then
            SERVER_NAME="slave2"
        else
            SERVER_NAME="unknown"
        fi
        
        echo -e "   Lectura #$i: server_id=${SERVER_ID} (${SERVER_NAME})"
    else
        echo -e "   ${RED}✗${NC} Lectura #$i: ERROR"
    fi
    
    # Pequeña pausa para ver mejor el round-robin
    sleep 0.2
done

echo ""
echo "--- Resumen de Distribución ---"
for server_id in "${!SERVER_COUNTS[@]}"; do
    count=${SERVER_COUNTS[$server_id]}
    
    if [ "$server_id" = "2" ]; then
        server_name="slave1"
    elif [ "$server_id" = "3" ]; then
        server_name="slave2"
    else
        server_name="unknown"
    fi
    
    echo -e "   server_id ${server_id} (${server_name}): ${count} lecturas (${count}0%)"
done

echo ""
echo -e "${YELLOW}Nota:${NC} Con round-robin, deberías ver aproximadamente 50% en cada esclavo"

#
# Parte 3: Verificar que escritura en puerto 3308 falla (solo lectura)
#
echo ""
echo ""
echo -e "${BLUE}=== Prueba 3: Verificar que puerto 3308 es SOLO LECTURA ===${NC}"
echo ""
echo "Intentando escribir a través del puerto de lectura (3308)..."

mysql -h127.0.0.1 -P3308 -uroot -p${MYSQL_ROOT_PASSWORD} -e "
INSERT INTO testdb.haproxy_test (message, server_id) 
VALUES ('Este INSERT debe fallar', @@server_id);
" 2>&1 | grep -q "super-read-only"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Correctamente bloqueado por read_only (esperado)"
else
    echo -e "${RED}✗${NC} ADVERTENCIA: La escritura no fue bloqueada"
fi

echo ""
echo "======================================"
echo "Prueba completada"
echo "======================================"
echo ""
echo -e "${YELLOW}Resumen:${NC}"
echo -e "  • Puerto 3307: Escrituras → Maestro (server_id=1)"
echo -e "  • Puerto 3308: Lecturas → Esclavos (server_id=2,3) con round-robin"
echo -e "  • Dashboard: http://localhost:8080/stats (admin/admin123)"