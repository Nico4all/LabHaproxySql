#!/bin/bash
set -e

# Este script extiende el entrypoint original de MySQL
# para iniciar xinetd y configurar replicación

# Determinar el rol basado en variables de entorno
ROLE="${MYSQL_ROLE:-master}"

echo "========================================="
echo "Iniciando MySQL en modo: $ROLE"
echo "Server ID: ${MYSQL_SERVER_ID}"
echo "========================================="

# Configurar el server-id en el archivo de configuración
if [ "$ROLE" = "master" ]; then
    sed -i "s/server-id = .*/server-id = ${MYSQL_SERVER_ID}/" /etc/mysql/conf.d/mysql-master.cnf
    # Eliminar la configuración de esclavo si existe
    rm -f /etc/mysql/conf.d/mysql-slave.cnf
else
    sed -i "s/server-id = .*/server-id = ${MYSQL_SERVER_ID}/" /etc/mysql/conf.d/mysql-slave.cnf
    # Eliminar la configuración de maestro si existe
    rm -f /etc/mysql/conf.d/mysql-master.cnf
fi

# Función para iniciar el servidor xinetd de health check en background
start_health_server() {
    echo "Iniciando xinetd para health checks..."
    xinetd -dontfork &
    XINETD_PID=$!
    echo "xinetd iniciado con PID: $XINETD_PID"
}

# Función para configurar replicación en esclavos
configure_replication() {
    if [ "$ROLE" != "master" ]; then
        echo "Esperando a que el maestro esté listo..."
        
        # Esperar a que el maestro esté disponible
        until mysql -h"${MYSQL_MASTER_HOST}" -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; do
            echo "Esperando al maestro MySQL..."
            sleep 3
        done
        
        echo "Maestro MySQL está listo. Configurando replicación..."
        
        # Configurar replicación con GTID
        # Configurar replicación con GTID
        # Temporalmente desactivar read_only para configurar replicación
        mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<-EOSQL
            SET GLOBAL read_only = OFF;
            SET GLOBAL super_read_only = OFF;
            
            STOP REPLICA;
            
            CHANGE REPLICATION SOURCE TO
                SOURCE_HOST='${MYSQL_MASTER_HOST}',
                SOURCE_PORT=3306,
                SOURCE_USER='${MYSQL_REPLICATION_USER}',
                SOURCE_PASSWORD='${MYSQL_REPLICATION_PASSWORD}',
                SOURCE_AUTO_POSITION=1;
            START REPLICA;
            
            SET GLOBAL read_only = ON;
            SET GLOBAL super_read_only = ON;
            
            SHOW REPLICA STATUS\G
EOSQL
        
        echo "Replicación configurada exitosamente."
    fi
}

# Iniciar MySQL en background usando el entrypoint original
echo "Iniciando servidor MySQL..."
docker-entrypoint.sh mysqld &
MYSQL_PID=$!

# Esperar a que MySQL esté listo
echo "Esperando a que MySQL esté listo..."
until mysqladmin ping -h"127.0.0.1" -uroot -p"${MYSQL_ROOT_PASSWORD}" --silent 2>/dev/null; do
    echo "MySQL aún no está listo..."
    sleep 2
done

echo "MySQL está listo."
# Si es esclavo, configurar read_only y super_read_only
if [ "$ROLE" != "master" ]; then
    echo "Configurando modo read-only para esclavo..."
    mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<-EOSQL
        SET GLOBAL read_only = ON;
        SET GLOBAL super_read_only = ON;
        SELECT @@read_only, @@super_read_only;
EOSQL
    echo "Modo read-only configurado."
fi

# Si es el maestro, crear usuario de replicación
if [ "$ROLE" = "master" ]; then
    echo "Creando usuario de replicación en el maestro..."
    mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<-EOSQL
        CREATE USER IF NOT EXISTS '${MYSQL_REPLICATION_USER}'@'%'
            IDENTIFIED WITH mysql_native_password BY '${MYSQL_REPLICATION_PASSWORD}';
        
        GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_REPLICATION_USER}'@'%';
        
        FLUSH PRIVILEGES;
        
        SELECT user, host FROM mysql.user WHERE user='${MYSQL_REPLICATION_USER}';
EOSQL
    echo "Usuario de replicación creado."
fi

# Iniciar xinetd para health checks
start_health_server

# Configurar replicación si es esclavo
if [ "$ROLE" != "master" ]; then
    configure_replication
fi

echo "========================================="
echo "Inicialización completa. MySQL está corriendo."
echo "Health check disponible en puerto 9200"
echo "========================================="

# Esperar a que los procesos terminen
wait $MYSQL_PID
