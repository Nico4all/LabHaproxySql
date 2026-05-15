#!/bin/bash
#
# MySQL Health Check Script
# Este script verifica el estado de MySQL y la replicación
# Devuelve HTTP 200 si está saludable, HTTP 503 si no
#

MYSQL_HOST="127.0.0.1"
MYSQL_PORT="3306"
MYSQL_USER="root"
MYSQL_PASSWORD="${MYSQL_ROOT_PASSWORD}"

# Función para retornar respuesta HTTP
return_ok() {
    printf "HTTP/1.1 200 OK\r\n"
    printf "Content-Type: text/plain\r\n"
    printf "Content-Length: 3\r\n"
    printf "\r\n"
    printf "OK\n"
}

return_error() {
    local message="$1"
    local length=$((${#message} + 1))
    printf "HTTP/1.1 503 Service Unavailable\r\n"
    printf "Content-Type: text/plain\r\n"
    printf "Content-Length: %d\r\n" "$length"
    printf "\r\n"
    printf "%s\n" "$message"
}

# Verificar que MySQL está corriendo (sin output)
if ! mysqladmin ping -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --silent >/dev/null 2>&1; then
    return_error "MySQL is not running"
    exit 1
fi

# Verificar si es maestro o esclavo revisando si tiene read_only desactivado
IS_READONLY=$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
    -e "SELECT @@read_only" -s -N 2>/dev/null | tr -d '[:space:]')

if [ "$IS_READONLY" = "0" ]; then
    # Es el MAESTRO - solo verificar que esté corriendo
    return_ok
    exit 0
else
    # Es un ESCLAVO - verificar que la replicación esté funcionando
    SLAVE_STATUS=$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        -e "SHOW REPLICA STATUS\G" 2>/dev/null)
    
    if [ -z "$SLAVE_STATUS" ]; then
        return_error "Replication not configured"
        exit 1
    fi
    
    # Verificar que ambos threads de replicación estén corriendo (trim espacios)
    IO_RUNNING=$(echo "$SLAVE_STATUS" | grep "Replica_IO_Running:" | awk '{print $2}' | tr -d '[:space:]')
    SQL_RUNNING=$(echo "$SLAVE_STATUS" | grep "Replica_SQL_Running:" | awk '{print $2}' | tr -d '[:space:]')
    
    if [ "$IO_RUNNING" != "Yes" ] || [ "$SQL_RUNNING" != "Yes" ]; then
        return_error "Replication threads not running: IO=$IO_RUNNING SQL=$SQL_RUNNING"
        exit 1
    fi
    
    # Verificar el lag de replicación (opcional, pero recomendado)
    SECONDS_BEHIND=$(echo "$SLAVE_STATUS" | grep "Seconds_Behind_Source:" | awk '{print $2}' | tr -d '[:space:]')
    
    if [ "$SECONDS_BEHIND" = "NULL" ] || [ -z "$SECONDS_BEHIND" ]; then
        return_error "Replication lag is NULL"
        exit 1
    fi
    
    # Si el lag es mayor a 30 segundos, marcar como no saludable (ajustable)
    if [ "$SECONDS_BEHIND" -gt 30 ] 2>/dev/null; then
        return_error "Replication lag too high: ${SECONDS_BEHIND}s"
        exit 1
    fi
    
    # Todo está bien
    return_ok
    exit 0
fi
