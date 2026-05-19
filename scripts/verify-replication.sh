#!/usr/bin/env bash
set -uo pipefail

source .env

echo "======================================"
echo "Verificando Estado de Replicacion MySQL"
echo "======================================"
echo ""

check_master() {
    echo "--- MySQL Master ---"
    echo "Contenedor: mysql-master"

    if ! docker exec mysql-master mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
        echo "[ERROR] No se pudo conectar al master"
        echo ""
        echo "--------------------------------------"
        echo ""
        return
    fi

    echo "[OK] Conexion exitosa"

    RESULT=$(docker exec mysql-master mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -N -B -e "SELECT @@hostname, @@server_id, @@read_only, @@super_read_only;" 2>/dev/null)

    HOSTNAME=$(echo "$RESULT" | awk '{print $1}')
    SERVER_ID=$(echo "$RESULT" | awk '{print $2}')
    READ_ONLY=$(echo "$RESULT" | awk '{print $3}')
    SUPER_READ_ONLY=$(echo "$RESULT" | awk '{print $4}')

    echo "Hostname: $HOSTNAME"
    echo "Server ID: $SERVER_ID"
    echo "read_only: $READ_ONLY"
    echo "super_read_only: $SUPER_READ_ONLY"

    if [ "$READ_ONLY" = "0" ] && [ "$SUPER_READ_ONLY" = "0" ]; then
        echo "[OK] Rol: MAESTRO / ESCRITURA"
    else
        echo "[ERROR] Rol incorrecto: el master esta en modo solo lectura"
    fi

    echo ""
    echo "--------------------------------------"
    echo ""
}

check_slave() {
    CONTAINER="$1"
    LABEL="$2"

    echo "--- $LABEL ---"
    echo "Contenedor: $CONTAINER"

    if ! docker exec "$CONTAINER" mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
        echo "[ERROR] No se pudo conectar"
        echo ""
        echo "--------------------------------------"
        echo ""
        return
    fi

    echo "[OK] Conexion exitosa"

    RESULT=$(docker exec "$CONTAINER" mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -N -B -e "SELECT @@hostname, @@server_id, @@read_only, @@super_read_only;" 2>/dev/null)

    HOSTNAME=$(echo "$RESULT" | awk '{print $1}')
    SERVER_ID=$(echo "$RESULT" | awk '{print $2}')
    READ_ONLY=$(echo "$RESULT" | awk '{print $3}')
    SUPER_READ_ONLY=$(echo "$RESULT" | awk '{print $4}')

    echo "Hostname: $HOSTNAME"
    echo "Server ID: $SERVER_ID"
    echo "read_only: $READ_ONLY"
    echo "super_read_only: $SUPER_READ_ONLY"

    if [ "$READ_ONLY" = "1" ] && [ "$SUPER_READ_ONLY" = "1" ]; then
        echo "[OK] Rol: ESCLAVO / SOLO LECTURA"
    else
        echo "[ERROR] Rol incorrecto: el esclavo no esta en modo solo lectura"
    fi

    echo ""
    echo "Estado de replicacion:"

    STATUS=$(docker exec "$CONTAINER" mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "SHOW REPLICA STATUS\G" 2>/dev/null)

    if [ -z "$STATUS" ]; then
        echo "[ERROR] Replicacion no configurada"
    else
        echo "$STATUS" | grep -E "Replica_IO_Running:|Replica_SQL_Running:|Seconds_Behind_Source:|Replica_SQL_Running_State:|Last_IO_Error:|Last_SQL_Error:|Auto_Position:"
    fi

    echo ""
    echo "--------------------------------------"
    echo ""
}

check_master
check_slave "mysql-slave1" "MySQL Slave 1"
check_slave "mysql-slave2" "MySQL Slave 2"

echo "======================================"
echo "Verificacion completada"
echo "======================================"
