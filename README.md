# MySQL Load Balancer con HAProxy - Parte 1: Replicación MySQL

Este proyecto implementa un balanceador de carga para bases de datos MySQL usando HAProxy con replicación maestro-esclavo y GTID.

##  Contenido

- [Arquitectura](#arquitectura)
- [Requisitos](#requisitos)
- [Instalación y Configuración](#instalación-y-configuración)
- [Parte 1: MySQL con Replicación](#parte-1-mysql-con-replicación)
- [Verificación y Pruebas](#verificación-y-pruebas)
- [Solución de Problemas](#solución-de-problemas)

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│                    Vagrant VM                            │
│  ┌───────────────────────────────────────────────────┐  │
│  │              Docker Network                        │  │
│  │  ┌─────────────────┐                              │  │
│  │  │  MySQL Master   │  (puerto 3306)               │  │
│  │  │  Server ID: 1   │  Health Check: 9200          │  │
│  │  │  read_only=OFF  │                              │  │
│  │  └────────┬────────┘                              │  │
│  │           │                                        │  │
│  │           │ Replicación GTID                      │  │
│  │           │                                        │  │
│  │     ┌─────┴─────┐                                 │  │
│  │     │           │                                 │  │
│  │  ┌──▼───────┐ ┌─▼──────────┐                     │  │
│  │  │ Slave 1  │ │  Slave 2   │                     │  │
│  │  │Server:2  │ │ Server:3   │                     │  │
│  │  │read_only │ │ read_only  │                     │  │
│  │  │  :3316   │ │   :3326    │                     │  │
│  │  │  HC:9201 │ │  HC:9202   │                     │  │
│  │  └──────────┘ └────────────┘                     │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Características Implementadas en Parte 1:

- ✅ 1 servidor MySQL maestro (escritura)
- ✅ 2 servidores MySQL esclavos (lectura)
- ✅ Replicación basada en GTID
- ✅ Health checks HTTP personalizados con xinetd
- ✅ Scripts de verificación y pruebas

## Requisitos

- VirtualBox >= 6.1
- Vagrant >= 2.3.0
- 4 GB RAM disponibles
- 10 GB espacio en disco

## Instalación y Configuración

### Paso 1: Clonar/Crear el Proyecto

```bash
# Crear directorio del proyecto
mkdir mysql-haproxy-loadbalancer
cd mysql-haproxy-loadbalancer

# Estructura de carpetas ya creada:
# .
# ├── Vagrantfile
# ├── .env
# ├── docker-compose.yml
# ├── mysql/
# │   ├── Dockerfile
# │   ├── healthcheck.sh
# │   ├── mysqlchk.xinetd
# │   ├── docker-entrypoint.sh
# │   ├── mysql-master.cnf
# │   └── mysql-slave.cnf
# └── scripts/
#     ├── verify-replication.sh
#     ├── verify-healthchecks.sh
#     └── test-replication.sh
```

### Paso 2: Iniciar la Máquina Virtual

```bash
# Iniciar y provisionar la VM
vagrant up

# Esto tomará varios minutos la primera vez
# Instalará: Ubuntu 22.04, Docker, Docker Compose, MySQL Client
```

### Paso 3: Conectarse a la VM

```bash
# SSH a la máquina virtual
vagrant ssh

# Navegar al directorio del proyecto
cd /vagrant
```

## Parte 1: MySQL con Replicación

### Paso 1: Construir y Levantar los Contenedores

```bash
# Dentro de la VM (/vagrant)

# Construir las imágenes personalizadas de MySQL
docker-compose build

# Levantar los contenedores
docker-compose up -d

# Verificar que los contenedores estén corriendo
docker-compose ps
```

**Salida esperada:**
```
NAME            IMAGE                     STATUS         PORTS
mysql-master    mysql-haproxy_mysql-master   Up 2 minutes   0.0.0.0:3306->3306/tcp, 0.0.0.0:9200->9200/tcp
mysql-slave1    mysql-haproxy_mysql-slave1   Up 2 minutes   0.0.0.0:3316->3306/tcp, 0.0.0.0:9201->9200/tcp
mysql-slave2    mysql-haproxy_mysql-slave2   Up 2 minutes   0.0.0.0:3326->3306/tcp, 0.0.0.0:9202->9200/tcp
```

### Paso 2: Verificar Logs de Inicialización

```bash
# Ver logs del maestro
docker-compose logs mysql-master

# Buscar estas líneas clave:
# - "MySQL está listo"
# - "Usuario de replicación creado"
# - "xinetd iniciado con PID"
# - "Inicialización completa"

# Ver logs de los esclavos
docker-compose logs mysql-slave1
docker-compose logs mysql-slave2

# Buscar estas líneas clave:
# - "Maestro MySQL está listo"
# - "Replicación configurada exitosamente"
# - "Inicialización completa"
```

### Paso 3: Verificar el Estado de la Replicación

```bash
# Ejecutar script de verificación
chmod +x scripts/verify-replication.sh
./scripts/verify-replication.sh
```

**Salida esperada:**

```
======================================
Verificando Estado de Replicación MySQL
======================================

--- MySQL Master ---
Host: mysql-master:3306
✓ Conexión exitosa
✓ Rol: MAESTRO (read_only=OFF)

Usuarios de replicación:
+-------------+------+
| user        | host |
+-------------+------+
| replicator  | %    |
+-------------+------+

Estado del binlog:
+------------------+----------+--------------+------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB |
+------------------+----------+--------------+------------------+
| mysql-bin.000003 |      157 |              |                  |
+------------------+----------+--------------+------------------+

--------------------------------------

--- MySQL Slave 1 ---
Host: mysql-slave1:3316
✓ Conexión exitosa
✓ Rol: ESCLAVO (read_only=ON)

Estado de replicación:
             Master_Host: mysql-master
     Replica_IO_Running: Yes
    Replica_SQL_Running: Yes
      Seconds_Behind_Master: 0
           Auto_Position: 1

--------------------------------------

--- MySQL Slave 2 ---
Host: mysql-slave2:3326
✓ Conexión exitosa
✓ Rol: ESCLAVO (read_only=ON)

Estado de replicación:
             Master_Host: mysql-master
     Replica_IO_Running: Yes
    Replica_SQL_Running: Yes
      Seconds_Behind_Master: 0
           Auto_Position: 1

======================================
```

**✅ Puntos clave a verificar:**
- Replica_IO_Running: **Yes**
- Replica_SQL_Running: **Yes**
- Seconds_Behind_Master: **0** (o muy bajo)
- Auto_Position: **1** (GTID habilitado)

### Paso 4: Verificar Health Checks HTTP

```bash
# Ejecutar script de verificación de health checks
chmod +x scripts/verify-healthchecks.sh
./scripts/verify-healthchecks.sh
```

**Salida esperada:**

```
======================================
Verificando Health Checks HTTP
======================================

--- MySQL Master (Puerto 9200) ---
✓ Health Check: OK (HTTP 200)
Respuesta: OK

--- MySQL Slave 1 (Puerto 9201) ---
✓ Health Check: OK (HTTP 200)
Respuesta: OK

--- MySQL Slave 2 (Puerto 9202) ---
✓ Health Check: OK (HTTP 200)
Respuesta: OK

======================================
```

**También puedes verificar manualmente:**

```bash
# Desde la VM
curl -i http://localhost:9200  # Master
curl -i http://localhost:9201  # Slave 1
curl -i http://localhost:9202  # Slave 2

# Desde tu máquina host (fuera de la VM)
curl -i http://localhost:9200
curl -i http://localhost:9201
curl -i http://localhost:9202
```

### Paso 5: Prueba de Escritura y Lectura

```bash
# Ejecutar script de prueba
chmod +x scripts/test-replication.sh
./scripts/test-replication.sh
```

**Salida esperada:**

```
======================================
Prueba de Escritura/Lectura
======================================

1. Creando tabla de prueba en el MAESTRO...
✓ Tabla creada

2. Insertando datos en el MAESTRO...
   Insertado registro #1
   Insertado registro #2
   Insertado registro #3
   Insertado registro #4
   Insertado registro #5
✓ Datos insertados

3. Esperando replicación (5 segundos)...

4. Verificando datos en el MAESTRO...
+------------------+
| total_registros  |
+------------------+
|                5 |
+------------------+

5. Verificando datos en ESCLAVO 1...
+------------------+
| total_registros  |
+------------------+
|                5 |
+------------------+

6. Verificando datos en ESCLAVO 2...
+------------------+
| total_registros  |
+------------------+
|                5 |
+------------------+

7. Intentando escribir en ESCLAVO 1 (debe fallar por read_only)...
✓ Correctamente bloqueado por read_only

======================================
```

## Verificación Manual Adicional

### Conectarse Directamente a MySQL

```bash
# Conectar al maestro
docker exec -it mysql-master mysql -uroot -prootpass123

# Dentro de MySQL:
mysql> SHOW MASTER STATUS;
mysql> SELECT @@server_id, @@read_only;
mysql> SHOW DATABASES;
mysql> USE testdb;
mysql> SHOW TABLES;
```

```bash
# Conectar a un esclavo
docker exec -it mysql-slave1 mysql -uroot -prootpass123

# Dentro de MySQL:
mysql> SHOW REPLICA STATUS\G
mysql> SELECT @@server_id, @@read_only;
```

### Verificar GTID

```bash
# En el maestro
docker exec -it mysql-master mysql -uroot -prootpass123 -e "SELECT @@GLOBAL.gtid_executed;"

# En los esclavos
docker exec -it mysql-slave1 mysql -uroot -prootpass123 -e "SELECT @@GLOBAL.gtid_executed;"
docker exec -it mysql-slave2 mysql -uroot -prootpass123 -e "SELECT @@GLOBAL.gtid_executed;"

# Los GTIDs deben coincidir
```

## Solución de Problemas

### Los contenedores no inician

```bash
# Ver logs detallados
docker-compose logs -f

# Reconstruir desde cero
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

### La replicación no funciona

```bash
# Ver el estado completo de la replicación
docker exec -it mysql-slave1 mysql -uroot -prootpass123 -e "SHOW REPLICA STATUS\G"

# Buscar errores específicos en:
# - Last_IO_Error
# - Last_SQL_Error

# Reiniciar replicación manualmente
docker exec -it mysql-slave1 mysql -uroot -prootpass123 -e "STOP REPLICA; START REPLICA;"
```

### Health check devuelve 503

```bash
# Verificar que xinetd esté corriendo
docker exec -it mysql-master ps aux | grep xinetd

# Ver logs de xinetd
docker exec -it mysql-master tail -f /var/log/syslog

# Probar el script manualmente
docker exec -it mysql-master /usr/local/bin/healthcheck.sh
```

### Lag de replicación alto

```bash
# Verificar el lag
docker exec -it mysql-slave1 mysql -uroot -prootpass123 -e "SHOW REPLICA STATUS\G" | grep Seconds_Behind

# Si es alto (>30s), el health check devolverá 503
# Causas comunes:
# - Mucha carga en el maestro
# - Recursos insuficientes
# - Red lenta
```

## Comandos Útiles

```bash
# Ver todos los contenedores
docker-compose ps

# Ver logs en tiempo real
docker-compose logs -f

# Detener todos los servicios
docker-compose down

# Detener y eliminar volúmenes (CUIDADO: borra todos los datos)
docker-compose down -v

# Reiniciar un servicio específico
docker-compose restart mysql-slave1

# Ver uso de recursos
docker stats

# Entrar a un contenedor
docker exec -it mysql-master bash
```



## Notas Importantes

1. **Contraseñas**: Las contraseñas están en el archivo `.env`.
2. **Persistencia**: Los datos se almacenan en volúmenes Docker. Se mantienen entre reinicios.
3. **Puertos**: Verificar que los puertos no estén en uso antes de iniciar.
4. **Recursos**: La VM necesita al menos 4 GB RAM para funcionar bien.

