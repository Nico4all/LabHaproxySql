# Paso a paso de implementación

## Proyecto 5: Balanceador de carga MySQL con HAProxy

Este proyecto implementa una arquitectura de balanceo de carga para bases de datos MySQL usando:

- 1 nodo MySQL maestro para escritura.
- 2 nodos MySQL esclavos para lectura.
- Replicación GTID entre maestro y esclavos.
- HAProxy 2.6 como balanceador TCP.
- Health checks con xinetd.
- Sysbench para pruebas de carga.
- Docker Compose para orquestar todos los servicios.

---

## 1. Clonar el repositorio

```bash
git clone <URL_DEL_REPOSITORIO>
cd <NOMBRE_DEL_REPOSITORIO>
```

---

## 2. Verificar archivo `.env`

El proyecto usa un archivo `.env` para manejar usuarios, contraseñas y puertos.

Ejemplo:

```env
MYSQL_ROOT_PASSWORD=rootpass123
MYSQL_DATABASE=testdb
MYSQL_USER=appuser
MYSQL_PASSWORD=apppass123

MYSQL_REPLICATION_USER=replicator
MYSQL_REPLICATION_PASSWORD=replicatorpass123

MYSQL_MASTER_PORT=3306
MYSQL_SLAVE1_PORT=3316
MYSQL_SLAVE2_PORT=3326

HAPROXY_WRITE_PORT=3307
HAPROXY_READ_PORT=3308
HAPROXY_STATS_PORT=8080
HAPROXY_STATS_USER=admin
HAPROXY_STATS_PASSWORD=admin123
```

---

## 3. Recomendación para usuarios Windows

Si el repositorio se clona desde Windows, es recomendable convertir los archivos a formato Linux para evitar errores con Docker.

```bash
find . -type f \( \
  -name "*.sh" -o \
  -name "*.yml" -o \
  -name "*.yaml" -o \
  -name "*.cfg" -o \
  -name "*.cnf" -o \
  -name "*.xinetd" -o \
  -name "Dockerfile" -o \
  -name ".env" -o \
  -name "*.md" \
\) -exec sed -i 's/\r$//' {} \;

chmod +x scripts/*.sh mysql/*.sh
```

Verificar que los scripts no tengan errores:

```bash
bash -n mysql/docker-entrypoint.sh
bash -n mysql/healthcheck.sh

for f in scripts/*.sh; do
  bash -n "$f"
done
```

---

## 4. Construir las imágenes

```bash
docker compose build --no-cache
```

Este comando construye las imágenes personalizadas de MySQL y Sysbench.

---

## 5. Levantar el nodo maestro

```bash
docker compose up -d mysql-master
```

Ver logs:

```bash
docker logs -f mysql-master
```

Esperar hasta ver un mensaje similar a:

```text
Inicialización completa. MySQL está corriendo.
Health check disponible en puerto 9200
```

Verificar health check del maestro:

```bash
curl http://localhost:9200
```

Respuesta esperada:

```text
OK
```

---

## 6. Levantar el primer esclavo

```bash
docker compose up -d mysql-slave1
```

Ver logs:

```bash
docker logs -f mysql-slave1
```

Verificar health check:

```bash
curl http://localhost:9201
```

Respuesta esperada:

```text
OK
```

---

## 7. Levantar el segundo esclavo

```bash
docker compose up -d mysql-slave2
```

Ver logs:

```bash
docker logs -f mysql-slave2
```

Verificar health check:

```bash
curl http://localhost:9202
```

Respuesta esperada:

```text
OK
```

---

## 8. Verificar contenedores activos

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Se deben observar los siguientes contenedores:

```text
mysql-master
mysql-slave1
mysql-slave2
```

Todos deben estar en estado `healthy`.

---

## 9. Verificar health checks

```bash
./scripts/verify-healthchecks.sh
```

Resultado esperado:

```text
MySQL Master: OK
MySQL Slave 1: OK
MySQL Slave 2: OK
```

---

## 10. Verificar replicación MySQL

```bash
./scripts/verify-replication.sh
```

Resultado esperado:

```text
MySQL Master:
read_only: 0
Rol: MAESTRO / ESCRITURA

MySQL Slave 1:
read_only: 1
Replica_IO_Running: Yes
Replica_SQL_Running: Yes
Seconds_Behind_Source: 0

MySQL Slave 2:
read_only: 1
Replica_IO_Running: Yes
Replica_SQL_Running: Yes
Seconds_Behind_Source: 0
```

---

## 11. Levantar HAProxy

```bash
docker compose up -d haproxy
```

Esperar unos segundos:

```bash
sleep 10
```

Verificar HAProxy:

```bash
./scripts/verify-haproxy.sh
```

Resultado esperado:

```text
mysql-master: UP
mysql-slave1: UP
mysql-slave2: UP
```

---

## 12. Acceder al dashboard de HAProxy

Abrir en el navegador:

```text
http://localhost:8080/stats
```

Credenciales:

```text
Usuario: admin
Contraseña: admin123
```

En el dashboard se deben observar los backends:

- `mysql_master_backend`
- `mysql_slaves_backend`

Todos deben estar en estado `UP`.

---

## 13. Probar escritura por puerto 3307 y lectura por puerto 3308

```bash
./scripts/test-haproxy-balancing.sh
```

Esta prueba valida:

- Escritura por el puerto `3307` hacia el maestro.
- Replicación de datos hacia los esclavos.
- Lectura por el puerto `3308`.
- Balanceo round-robin entre `mysql-slave1` y `mysql-slave2`.
- Bloqueo de escritura en el puerto de lectura.

Resultado esperado:

```text
Puerto 3307: Escrituras -> Maestro
Puerto 3308: Lecturas -> Esclavos
Replicación exitosa
Lecturas balanceadas entre slave1 y slave2
```

---

## 14. Levantar Sysbench

```bash
docker compose up -d sysbench
```

Verificar contenedor:

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

Debe aparecer:

```text
sysbench
```

---

## 15. Preparar datos para Sysbench

```bash
./scripts/sysbench-prepare.sh
```

Este comando crea las tablas de prueba `sbtest`.

Esperar unos segundos para que los datos se repliquen:

```bash
sleep 5
```

---

## 16. Ejecutar prueba Sysbench de lectura

```bash
./scripts/sysbench-read.sh
```

Esta prueba se ejecuta contra el puerto `3308`, que corresponde al backend de lectura balanceado entre los esclavos.

Se deben revisar métricas como:

- Transacciones por segundo.
- Consultas por segundo.
- Latencia promedio.
- Percentil 95 de latencia.

---

## 17. Ejecutar prueba Sysbench de lectura/escritura

```bash
./scripts/sysbench-write.sh
```

Esta prueba se ejecuta contra el puerto `3307`, que corresponde al backend de escritura hacia el maestro.

Se deben revisar métricas como:

- TPS.
- QPS.
- Latencia.
- Errores.
- Reconexiones.

---

## 18. Limpiar datos de Sysbench

Solo ejecutar al finalizar las pruebas:

```bash
./scripts/sysbench-cleanup.sh
```

Importante:

Si se ejecuta `sysbench-cleanup.sh`, para volver a correr `sysbench-read.sh` o `sysbench-write.sh` primero se debe ejecutar nuevamente:

```bash
./scripts/sysbench-prepare.sh
```

---

## 19. Simular caída de un esclavo

Detener `mysql-slave1`:

```bash
docker stop mysql-slave1
```

Esperar a que HAProxy detecte la caída:

```bash
sleep 10
```

Verificar HAProxy:

```bash
./scripts/verify-haproxy.sh
```

En el dashboard de HAProxy se debe observar que `mysql-slave1` aparece como `DOWN`, mientras `mysql-slave2` sigue disponible.

---

## 20. Verificar que la lectura continúa funcionando

```bash
source .env

for i in {1..5}; do
  mysql -h127.0.0.1 -P"$HAPROXY_READ_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
    -e "SELECT @@hostname AS host, @@server_id AS server_id;"
done
```

Las lecturas deben responder desde el esclavo disponible.

---

## 21. Recuperar el esclavo caído

```bash
docker start mysql-slave1
```

Esperar recuperación:

```bash
sleep 20
```

Verificar HAProxy:

```bash
./scripts/verify-haproxy.sh
```

Resultado esperado:

```text
mysql-slave1: UP
mysql-slave2: UP
```

---

## 22. Comandos útiles

Ver contenedores:

```bash
docker ps
```

Ver logs del maestro:

```bash
docker logs -f mysql-master
```

Ver logs de un esclavo:

```bash
docker logs -f mysql-slave1
docker logs -f mysql-slave2
```

Ver logs de HAProxy:

```bash
docker logs -f haproxy
```

Apagar todo sin borrar volúmenes:

```bash
docker compose down
```

Apagar todo y borrar volúmenes:

```bash
docker compose down -v
```

Nota: usar `down -v` solo si se quiere reiniciar toda la base de datos desde cero.

---

## 23. Puertos principales

| Servicio | Puerto | Uso |
|---|---:|---|
| MySQL Master | 3306 | Acceso directo al maestro |
| MySQL Slave 1 | 3316 | Acceso directo al esclavo 1 |
| MySQL Slave 2 | 3326 | Acceso directo al esclavo 2 |
| HAProxy Escritura | 3307 | Escrituras hacia el maestro |
| HAProxy Lectura | 3308 | Lecturas hacia esclavos |
| HAProxy Dashboard | 8080 | Panel de monitoreo |
| Health Master | 9200 | Health check maestro |
| Health Slave 1 | 9201 | Health check esclavo 1 |
| Health Slave 2 | 9202 | Health check esclavo 2 |

---

## 24. Resumen de arquitectura

La arquitectura final queda así:

```text
Cliente / Sysbench
        |
        v
      HAProxy
   /     |      \
3307   3308    8080
 |       |       |
 v       v       v
Master  Slaves  Dashboard
MySQL   MySQL
        |
        +--> mysql-slave1
        +--> mysql-slave2
```

El tráfico de escritura entra por `3307` y se dirige al maestro.  
El tráfico de lectura entra por `3308` y se balancea entre los dos esclavos.  
Los health checks se ejecutan mediante xinetd en cada nodo MySQL y HAProxy los usa para detectar nodos disponibles o caídos.
