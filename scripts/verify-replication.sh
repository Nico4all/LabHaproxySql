#!/bin/bash
#
# Script para verificar el estado de la replicación MySQL
#

source .env

echo "======================================"
echo "Verificando Estado de Replicación MySQL"
echo "======================================"
echo ""

# Función para verificar el estado de un servidor
check_server() {
    local name=$1
    local host=$2
    local port=$3
    
    echo "--- $name ---"
    echo "Host: $host:$port"
    
    # Verificar conexión
    if docker exec -it $host mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SELECT 1" >/dev/null 2>&1; then
        echo "✓ Conexión exitosa"
        
        # Verificar si es maestro o esclavo
        IS_READONLY=$(docker exec -it $host mysql -uroot -p${MYSQL_ROOT_PASSWORD} -s -N -e "SELECT @@read_only" 2>/dev/null | tr -d '\r')
        
        if [ "$IS_READONLY" = "0" ]; then
            echo "✓ Rol: MAESTRO (read_only=OFF)"
            echo ""
            echo "Usuarios de replicación:"
            docker exec -it $host mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SELECT user, host FROM mysql.user WHERE user='${MYSQL_REPLICATION_USER}'"
            echo ""
            echo "Estado del binlog:"
            docker exec -it $host mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW MASTER STATUS"
        else
            echo "✓ Rol: ESCLAVO (read_only=ON)"
            echo ""
            echo "Estado de replicación:"
            docker exec -it $host mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW REPLICA STATUS\G" | grep -E "Replica_IO_Running|Replica_SQL_Running|Seconds_Behind|Master_Host|Auto_Position"
        fi
    else
        echo "✗ No se pudo conectar"
    fi
    
    echo ""
    echo "--------------------------------------"
    echo ""
}

# Verificar maestro
check_server "MySQL Master" "mysql-master" "${MYSQL_MASTER_PORT}"

# Verificar esclavos
check_server "MySQL Slave 1" "mysql-slave1" "${MYSQL_SLAVE1_PORT}"
check_server "MySQL Slave 2" "mysql-slave2" "${MYSQL_SLAVE2_PORT}"

echo "======================================"
echo "Verificación completada"
echo "======================================"