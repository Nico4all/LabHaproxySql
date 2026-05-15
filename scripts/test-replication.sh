#!/bin/bash
#
# Script para probar escritura en maestro y lectura en esclavos
#

source .env

echo "======================================"
echo "Prueba de Escritura/Lectura"
echo "======================================"
echo ""

# 1. Crear una tabla de prueba en el maestro
echo "1. Creando tabla de prueba en el MAESTRO..."
docker exec -it mysql-master mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "
USE ${MYSQL_DATABASE};
DROP TABLE IF EXISTS test_replication;
CREATE TABLE test_replication (
    id INT AUTO_INCREMENT PRIMARY KEY,
    message VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
"
echo "✓ Tabla creada"
echo ""

# 2. Insertar datos en el maestro
echo "2. Insertando datos en el MAESTRO..."
for i in {1..5}; do
    docker exec -it mysql-master mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "
    USE ${MYSQL_DATABASE};
    INSERT INTO test_replication (message) VALUES ('Mensaje de prueba #$i desde el maestro');
    "
    echo "   Insertado registro #$i"
done
echo "✓ Datos insertados"
echo ""

# Esperar a que se replique
echo "3. Esperando replicación (5 segundos)..."
sleep 5
echo ""

# 4. Verificar datos en el maestro
echo "4. Verificando datos en el MAESTRO..."
docker exec -it mysql-master mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "
USE ${MYSQL_DATABASE};
SELECT COUNT(*) as total_registros FROM test_replication;
SELECT * FROM test_replication;
"
echo ""

# 5. Verificar datos en esclavo 1
echo "5. Verificando datos en ESCLAVO 1..."
docker exec -it mysql-slave1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "
USE ${MYSQL_DATABASE};
SELECT COUNT(*) as total_registros FROM test_replication;
SELECT * FROM test_replication;
"
echo ""

# 6. Verificar datos en esclavo 2
echo "6. Verificando datos en ESCLAVO 2..."
docker exec -it mysql-slave2 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "
USE ${MYSQL_DATABASE};
SELECT COUNT(*) as total_registros FROM test_replication;
SELECT * FROM test_replication;
"
echo ""

# 7. Intentar escribir en un esclavo (debe fallar)
echo "7. Intentando escribir en ESCLAVO 1 (debe fallar por read_only)..."
docker exec -it mysql-slave1 mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "
USE ${MYSQL_DATABASE};
INSERT INTO test_replication (message) VALUES ('Intento de escritura en esclavo');
" 2>&1 | grep -i "read-only" && echo "✓ Correctamente bloqueado por read_only" || echo "✗ Error inesperado"

echo ""
echo "======================================"
echo "Prueba completada"
echo "======================================"
