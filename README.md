# Proyecto 5: Balanceo de carga de bases de datos MySQL con HAProxy

## 1. Información general

Este proyecto implementa una arquitectura de base de datos MySQL con replicación maestro-esclavo y balanceo de carga mediante HAProxy. El tráfico de escritura se dirige únicamente al nodo maestro y el tráfico de lectura se distribuye entre los nodos esclavos.

El sistema está completamente contenerizado con Docker y orquestado con Docker Compose.

---

## 2. Objetivo del proyecto

Implementar un balanceador de carga para bases de datos MySQL utilizando HAProxy en modo TCP, con replicación basada en GTID y health checks personalizados expuestos mediante xinetd.

El sistema debe permitir:

- Separar tráfico de escritura y lectura.
- Enviar escrituras únicamente al nodo maestro.
- Distribuir lecturas entre los nodos esclavos.
- Detectar automáticamente nodos caídos o no saludables.
- Visualizar el estado de los backends desde el dashboard de HAProxy.
- Ejecutar pruebas de rendimiento con Sysbench.

---

## 3. Herramientas utilizadas

| Herramienta | Versión / uso |
|---|---|
| MySQL | MySQL 8 bookworm|
| HAProxy | HAProxy 2.6 |
| xinetd | Publicación de health checks HTTP |
| Docker | Contenerización |
| Docker Compose | Orquestación de servicios |
| Sysbench | Pruebas de rendimiento |
| Vagrant | Entorno de laboratorio opcional |

---

## 4. Arquitectura general

```text
Cliente / Aplicación
        |
        |--------------------------|
        |                          |
        v                          v
 Puerto 3307                  Puerto 3308
 Escritura                    Lectura
        |                          |
        v                          v
      HAProxy ---------------- HAProxy
        |                          |
        v                          v
 MySQL Master              MySQL Slave 1
 Escritura                 Lectura
        |
        | Replicación GTID
        v
 MySQL Slave 2
 Lectura
```

---

## 5. Servicios del proyecto

| Servicio | Función | Puerto interno | Puerto en host |
|---|---|---:|---:|
| mysql-master | Nodo maestro MySQL | 3306 | 3306 |
| mysql-slave1 | Primer nodo esclavo | 3306 | 3316 |
| mysql-slave2 | Segundo nodo esclavo | 3306 | 3326 |
| haproxy | Balanceador de carga | 3307 / 3308 / 8080 | 3307 / 3308 / 8080 |
| sysbench | Pruebas de rendimiento | N/A | N/A |

---

## 6. Puertos principales

| Puerto | Uso |
|---:|---|
| 3306 | MySQL maestro desde el host |
| 3316 | MySQL esclavo 1 desde el host |
| 3326 | MySQL esclavo 2 desde el host |
| 3307 | Entrada HAProxy para escrituras |
| 3308 | Entrada HAProxy para lecturas |
| 8080 | Dashboard web de HAProxy |
| 9200 | Health check del maestro desde el host |
| 9201 | Health check del esclavo 1 desde el host |
| 9202 | Health check del esclavo 2 desde el host |

Dentro de la red Docker, cada contenedor MySQL expone su health check en el puerto interno `9200`. Por eso HAProxy consulta:

```text
mysql-master:9200
mysql-slave1:9200
mysql-slave2:9200
```

Aunque en el host se publiquen como `9200`, `9201` y `9202` para evitar conflicto de puertos.

---

## 7. Estructura del proyecto

```text
LabHaproxySql-main/
│
├── .env
├── docker-compose.yml
├── Vagrantfile
├── leeme.md
│
├── haproxy/
│   └── haproxy.cfg
│
├── mysql/
│   ├── Dockerfile
│   ├── docker-entrypoint.sh
│   ├── healthcheck.sh
│   ├── mysql-master.cnf
│   ├── mysql-slave.cnf
│   └── mysqlchk.xinetd
│
├── sysbench/
│   └── Dockerfile
│
└── scripts/
    ├── quick-start.sh
    ├── quick-start-haproxy.sh
    ├── verify-healthchecks.sh
    ├── verify-replication.sh
    ├── verify-haproxy.sh
    ├── test-replication.sh
    ├── test-haproxy-balancing.sh
    ├── test-failover-slave.sh
    ├── sysbench-prepare.sh
    ├── sysbench-read.sh
    ├── sysbench-write.sh
    └── sysbench-cleanup.sh
```

---

## 8. Variables de entorno

El proyecto utiliza un archivo `.env` para centralizar usuarios, contraseñas y puertos.

Ejemplo:

```env
# Configuración de MySQL
MYSQL_ROOT_PASSWORD=rootpass123
MYSQL_REPLICATION_USER=replicator
MYSQL_REPLICATION_PASSWORD=replicatorpass123
MYSQL_DATABASE=testdb
MYSQL_USER=appuser
MYSQL_PASSWORD=apppass123

# Puertos MySQL publicados en el host
MYSQL_MASTER_PORT=3306
MYSQL_SLAVE1_PORT=3316
MYSQL_SLAVE2_PORT=3326

# Puertos de health check publicados en el host
MASTER_HEALTH_PORT=9200
SLAVE1_HEALTH_PORT=9201
SLAVE2_HEALTH_PORT=9202

# Configuración de HAProxy
HAPROXY_WRITE_PORT=3307
HAPROXY_READ_PORT=3308
HAPROXY_STATS_PORT=8080
HAPROXY_STATS_USER=admin
HAPROXY_STATS_PASSWORD=admin123

# Server IDs para replicación
SERVER_ID_MASTER=1
SERVER_ID_SLAVE1=2
SERVER_ID_SLAVE2=3
```

---

## 9. Requisitos previos

Antes de ejecutar el proyecto, la máquina debe tener instalado:

- Docker
- Docker Compose
- Git, opcional
- Vagrant, opcional si se usa la máquina virtual del laboratorio

Verificar instalación:

```bash
docker --version
docker compose version
```

---

## 10. Construcción y ejecución del proyecto

### 10.1. Levantar el proyecto desde cero

```bash
docker compose down -v
docker compose build --no-cache
docker compose up -d
```

### 10.2. Verificar contenedores

```bash
docker compose ps
```

Resultado esperado:

```text
mysql-master    running
mysql-slave1    running
mysql-slave2    running
haproxy         running
sysbench        running
```

---

## 11. Funcionamiento de MySQL

El proyecto usa tres instancias MySQL:

- `mysql-master`: nodo principal, recibe escrituras.
- `mysql-slave1`: nodo esclavo, recibe lecturas.
- `mysql-slave2`: nodo esclavo, recibe lecturas.

La replicación se realiza con GTID-based replication, usando:

```sql
SOURCE_AUTO_POSITION = 1
```

Esto permite que los esclavos repliquen automáticamente desde el maestro sin depender de posiciones manuales de binlog.

---

## 12. Configuración del maestro

El nodo maestro se configura con:

- `server-id = 1`
- `log-bin` habilitado
- `gtid_mode = ON`
- `enforce_gtid_consistency = ON`
- `read_only = OFF`

El maestro crea el usuario de replicación:

```sql
CREATE USER IF NOT EXISTS 'replicator'@'%'
IDENTIFIED WITH mysql_native_password BY 'replicatorpass123';

GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';
FLUSH PRIVILEGES;
```

---

## 13. Configuración de esclavos

Los esclavos se configuran con:

- `server-id = 2` para `mysql-slave1`
- `server-id = 3` para `mysql-slave2`
- `gtid_mode = ON`
- `enforce_gtid_consistency = ON`
- `read_only = ON`
- `super_read_only = ON`

Cada esclavo se conecta al maestro con:

```sql
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST='mysql-master',
    SOURCE_PORT=3306,
    SOURCE_USER='replicator',
    SOURCE_PASSWORD='replicatorpass123',
    SOURCE_AUTO_POSITION=1;

START REPLICA;
```

---

## 14. Health checks con xinetd

Cada nodo MySQL ejecuta un health check expuesto mediante xinetd.

El servicio xinetd escucha internamente en:

```text
9200
```

Cada contenedor MySQL tiene su propio puerto interno `9200`, por lo que no hay conflicto dentro de la red Docker.

En el host se publican así:

| Nodo | Puerto interno | Puerto host |
|---|---:|---:|
| mysql-master | 9200 | 9200 |
| mysql-slave1 | 9200 | 9201 |
| mysql-slave2 | 9200 | 9202 |

---

## 15. Validación manual de health checks

Desde el host:

```bash
curl -i http://localhost:9200
curl -i http://localhost:9201
curl -i http://localhost:9202
```

Resultado esperado para el maestro:

```text
HTTP/1.1 200 OK
Content-Type: text/plain
Connection: close

OK - Master is writable
```

Resultado esperado para los esclavos:

```text
HTTP/1.1 200 OK
Content-Type: text/plain
Connection: close

OK - Slave replication healthy. Lag=0
```

Desde el contenedor HAProxy:

```bash
docker exec -it haproxy sh
wget -S -O- http://mysql-master:9200
wget -S -O- http://mysql-slave1:9200
wget -S -O- http://mysql-slave2:9200
exit
```

---

## 16. Configuración de HAProxy

HAProxy tiene dos frontends principales:

| Frontend | Puerto | Uso | Backend |
|---|---:|---|---|
| mysql_write | 3307 | Escrituras | mysql_master_backend |
| mysql_read | 3308 | Lecturas | mysql_slaves_backend |

---

## 17. Backend de escritura

El backend de escritura envía todo el tráfico al maestro.

Ejemplo recomendado:

```cfg
backend mysql_master_backend
    mode tcp
    option tcp-check
    tcp-check connect port 9200
    tcp-check send GET\ /\ HTTP/1.0\r\n\r\n
    tcp-check expect string OK
    server mysql-master mysql-master:3306 check inter 3s fall 3 rise 2
```

---

## 18. Backend de lectura

El backend de lectura distribuye tráfico entre los esclavos.

Ejemplo recomendado:

```cfg
backend mysql_slaves_backend
    mode tcp
    balance roundrobin
    option tcp-check
    tcp-check connect port 9200
    tcp-check send GET\ /\ HTTP/1.0\r\n\r\n
    tcp-check expect string OK
    server mysql-slave1 mysql-slave1:3306 check inter 3s fall 3 rise 2
    server mysql-slave2 mysql-slave2:3306 check inter 3s fall 3 rise 2
```

Se utiliza `tcp-check` porque HAProxy trabaja en modo TCP y el health check expuesto por xinetd responde HTTP simple. El chequeo valida que la respuesta contenga la palabra `OK`.

---

## 19. Dashboard de HAProxy

El dashboard está disponible en:

```text
http://localhost:8080/stats
```

Credenciales:

```text
Usuario: admin
Contraseña: admin123
```

En el dashboard se deben observar:

- `mysql-master` en estado `UP`.
- `mysql-slave1` en estado `UP`.
- `mysql-slave2` en estado `UP`.
- Frontend de escritura abierto en el puerto `3307`.
- Frontend de lectura abierto en el puerto `3308`.

---

## 20. Verificación de HAProxy por consola

```bash
curl -s -u admin:admin123 "http://localhost:8080/stats;csv" | grep mysql
```

También se puede ejecutar:

```bash
./scripts/verify-haproxy.sh
```

Resultado esperado:

```text
Backend: mysql_master_backend
  ✓ mysql-master: UP

Backend: mysql_slaves_backend
  ✓ mysql-slave1: UP
  ✓ mysql-slave2: UP
```

---

## 21. Verificación de replicación

Ejecutar:

```bash
./scripts/verify-replication.sh
```

También se puede revisar manualmente:

```bash
docker exec -it mysql-slave1 mysql -uroot -p
SHOW REPLICA STATUS\G
```

El resultado esperado debe incluir:

```text
Replica_IO_Running: Yes
Replica_SQL_Running: Yes
Seconds_Behind_Source: 0
Auto_Position: 1
```

Repetir en `mysql-slave2`:

```bash
docker exec -it mysql-slave2 mysql -uroot -p
SHOW REPLICA STATUS\G
```

---

## 22. Prueba de separación de tráfico

El sistema debe demostrar:

- Escrituras por el puerto `3307`.
- Lecturas por el puerto `3308`.
- El puerto de lectura no debe aceptar escrituras porque los esclavos están en modo `read_only` y `super_read_only`.

Ejecutar:

```bash
./scripts/test-haproxy-balancing.sh
```

Prueba manual de escritura:

```bash
mysql -h 127.0.0.1 -P 3307 -uappuser -papppass123 testdb
```

Dentro de MySQL:

```sql
CREATE TABLE IF NOT EXISTS prueba_lb (
    id INT AUTO_INCREMENT PRIMARY KEY,
    mensaje VARCHAR(100),
    creado TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO prueba_lb (mensaje) VALUES ('Prueba escritura por HAProxy puerto 3307');
SELECT * FROM prueba_lb;
```

Prueba manual de lectura:

```bash
mysql -h 127.0.0.1 -P 3308 -uappuser -papppass123 testdb
```

Dentro de MySQL:

```sql
SELECT * FROM prueba_lb;
```

---

## 23. Prueba de caída de un esclavo

Para demostrar detección automática de fallos:

```bash
docker compose stop mysql-slave1
```

Esperar unos segundos y revisar dashboard:

```bash
curl -s -u admin:admin123 "http://localhost:8080/stats;csv" | grep mysql-slave1
```

Resultado esperado:

```text
mysql-slave1 DOWN
```

Luego levantar nuevamente:

```bash
docker compose start mysql-slave1
```

Esperar y revisar:

```bash
curl -s -u admin:admin123 "http://localhost:8080/stats;csv" | grep mysql-slave1
```

Resultado esperado:

```text
mysql-slave1 UP
```

Si existe el script, usar:

```bash
./scripts/test-failover-slave.sh
```

---

## 24. Pruebas con Sysbench

Sysbench se utiliza para realizar benchmarks de lectura y escritura.

### 24.1. Preparar datos de prueba

```bash
./scripts/sysbench-prepare.sh
```

Comando equivalente:

```bash
docker exec -it sysbench sysbench oltp_read_write \
  --db-driver=mysql \
  --mysql-host=haproxy \
  --mysql-port=3307 \
  --mysql-user=appuser \
  --mysql-password=apppass123 \
  --mysql-db=testdb \
  --tables=4 \
  --table-size=10000 \
  prepare
```

---

### 24.2. Benchmark de lectura

Requisito del proyecto:

- 8 hilos
- modo read-only
- puerto 3308
- duración 60 segundos

Ejecutar:

```bash
./scripts/sysbench-read.sh
```

Comando equivalente:

```bash
docker exec -it sysbench sysbench oltp_read_only \
  --db-driver=mysql \
  --mysql-host=haproxy \
  --mysql-port=3308 \
  --mysql-user=appuser \
  --mysql-password=apppass123 \
  --mysql-db=testdb \
  --tables=4 \
  --table-size=10000 \
  --threads=8 \
  --time=60 \
  --report-interval=10 \
  run
```

---

### 24.3. Benchmark de escritura / lectura-escritura

Requisito del proyecto:

- 8 hilos
- modo read/write
- puerto 3307
- duración 60 segundos

Ejecutar:

```bash
./scripts/sysbench-write.sh
```

Comando equivalente:

```bash
docker exec -it sysbench sysbench oltp_read_write \
  --db-driver=mysql \
  --mysql-host=haproxy \
  --mysql-port=3307 \
  --mysql-user=appuser \
  --mysql-password=apppass123 \
  --mysql-db=testdb \
  --tables=4 \
  --table-size=10000 \
  --threads=8 \
  --time=60 \
  --report-interval=10 \
  run
```

---

### 24.4. Limpiar datos de Sysbench

```bash
./scripts/sysbench-cleanup.sh
```

Comando equivalente:

```bash
docker exec -it sysbench sysbench oltp_read_write \
  --db-driver=mysql \
  --mysql-host=haproxy \
  --mysql-port=3307 \
  --mysql-user=appuser \
  --mysql-password=apppass123 \
  --mysql-db=testdb \
  --tables=4 \
  cleanup
```

---

## 25. Evidencias esperadas para la entrega

Agregar capturas o resultados de consola de las siguientes pruebas:

### 25.1. Dashboard HAProxy

Captura esperada:

- `mysql-master` en `UP`.
- `mysql-slave1` en `UP`.
- `mysql-slave2` en `UP`.

Ubicación sugerida:

```text
evidencias/dashboard-haproxy-up.png
```

---

### 25.2. Verificación de health checks

Comandos:

```bash
curl -i http://localhost:9200
curl -i http://localhost:9201
curl -i http://localhost:9202
```

Captura esperada:

```text
HTTP/1.1 200 OK
OK - Master is writable
OK - Slave replication healthy. Lag=0
```

---

### 25.3. Verificación de replicación

Comando:

```bash
./scripts/verify-replication.sh
```

Captura esperada:

```text
Replica_IO_Running: Yes
Replica_SQL_Running: Yes
Seconds_Behind_Source: 0
Auto_Position: 1
```

---

### 25.4. Separación de tráfico

Comando:

```bash
./scripts/test-haproxy-balancing.sh
```

Debe evidenciar:

- Escritura por `3307`.
- Lectura por `3308`.
- Lecturas distribuidas entre esclavos.

---

### 25.5. Caída de un esclavo

Comandos:

```bash
docker compose stop mysql-slave1
curl -s -u admin:admin123 "http://localhost:8080/stats;csv" | grep mysql-slave1
```

Luego:

```bash
docker compose start mysql-slave1
curl -s -u admin:admin123 "http://localhost:8080/stats;csv" | grep mysql-slave1
```

Debe evidenciar:

- `mysql-slave1 DOWN` al detener el contenedor.
- `mysql-slave1 UP` al levantarlo nuevamente.

---

### 25.6. Benchmark Sysbench read-only

Comando:

```bash
./scripts/sysbench-read.sh
```

Guardar:

- TPS
- latencia promedio
- número de consultas
- duración de la prueba

---

### 25.7. Benchmark Sysbench read/write

Comando:

```bash
./scripts/sysbench-write.sh
```

Guardar:

- TPS
- latencia promedio
- número de transacciones
- duración de la prueba

---

## 26. Tabla de resultados Sysbench

Completar después de ejecutar las pruebas:

| Prueba | Puerto | Modo | Hilos | Duración | TPS | Latencia promedio |
|---|---:|---|---:|---:|---:|---:|
| Lectura | 3308 | read-only | 8 | 60 s | Pendiente | Pendiente |
| Escritura | 3307 | read/write | 8 | 60 s | Pendiente | Pendiente |

---

## 27. Comandos útiles

### Ver logs del maestro

```bash
docker logs mysql-master --tail=80
```

### Ver logs del esclavo 1

```bash
docker logs mysql-slave1 --tail=80
```

### Ver logs del esclavo 2

```bash
docker logs mysql-slave2 --tail=80
```

### Ver logs de HAProxy

```bash
docker logs haproxy --tail=80
```

### Entrar al contenedor HAProxy

```bash
docker exec -it haproxy sh
```

### Entrar al maestro MySQL

```bash
docker exec -it mysql-master mysql -uroot -p
```

### Entrar al esclavo 1

```bash
docker exec -it mysql-slave1 mysql -uroot -p
```

### Entrar al esclavo 2

```bash
docker exec -it mysql-slave2 mysql -uroot -p
```

---

## 28. Solución de problemas comunes

### Problema: HAProxy muestra backends DOWN

Verificar primero los health checks:

```bash
curl -i http://localhost:9200
curl -i http://localhost:9201
curl -i http://localhost:9202
```

Luego verificar desde el contenedor HAProxy:

```bash
docker exec -it haproxy sh
wget -S -O- http://mysql-master:9200
wget -S -O- http://mysql-slave1:9200
wget -S -O- http://mysql-slave2:9200
exit
```

Si responden `200 OK`, el problema está en la configuración de HAProxy.

Usar `tcp-check` en lugar de `httpchk`:

```cfg
option tcp-check
tcp-check connect port 9200
tcp-check send GET\ /\ HTTP/1.0\r\n\r\n
tcp-check expect string OK
```

---

### Problema: xinetd no responde

Revisar si xinetd está corriendo:

```bash
docker exec -it mysql-master ps aux | grep xinetd
docker exec -it mysql-slave1 ps aux | grep xinetd
docker exec -it mysql-slave2 ps aux | grep xinetd
```

Verificar el archivo de configuración:

```bash
docker exec -it mysql-master cat /etc/xinetd.d/mysqlchk
```

---

### Problema: conflicto de puertos 9200

No publicar los tres contenedores con el mismo puerto en el host.

Incorrecto:

```yaml
ports:
  - "9200:9200"
```

repetido en los tres servicios.

Correcto:

```yaml
mysql-master:
  ports:
    - "9200:9200"

mysql-slave1:
  ports:
    - "9201:9200"

mysql-slave2:
  ports:
    - "9202:9200"
```

Dentro de HAProxy sí se usa `9200` para todos porque cada contenedor tiene IP propia.

---

### Problema: replicación no inicia

Revisar estado:

```bash
docker exec -it mysql-slave1 mysql -uroot -p -e "SHOW REPLICA STATUS\G"
docker exec -it mysql-slave2 mysql -uroot -p -e "SHOW REPLICA STATUS\G"
```

Validar que aparezca:

```text
Replica_IO_Running: Yes
Replica_SQL_Running: Yes
```

Si aparece error de usuario o contraseña, revisar `.env` y el usuario `replicator` en el maestro.

---

### Problema: Sysbench no conecta

Verificar que HAProxy esté activo:

```bash
docker compose ps
curl -s -u admin:admin123 "http://localhost:8080/stats;csv" | grep mysql
```

Probar conexión manual:

```bash
docker exec -it sysbench mysql -hhaproxy -P3307 -uappuser -papppass123 testdb -e "SELECT 1;"
docker exec -it sysbench mysql -hhaproxy -P3308 -uappuser -papppass123 testdb -e "SELECT 1;"
```

---

## 29. Limpieza completa del entorno

Para borrar contenedores, red y volúmenes:

```bash
docker compose down -v
```

Para reconstruir todo desde cero:

```bash
docker compose build --no-cache
docker compose up -d
```

---

## 30. Checklist final de entrega

Antes de entregar, verificar:

- [ ] Docker Compose levanta todos los servicios.
- [ ] MySQL maestro está activo.
- [ ] MySQL esclavo 1 está activo.
- [ ] MySQL esclavo 2 está activo.
- [ ] Replicación GTID funciona en ambos esclavos.
- [ ] `Replica_IO_Running = Yes`.
- [ ] `Replica_SQL_Running = Yes`.
- [ ] `Seconds_Behind_Source = 0`.
- [ ] Health check del maestro responde `HTTP 200 OK`.
- [ ] Health check del esclavo 1 responde `HTTP 200 OK`.
- [ ] Health check del esclavo 2 responde `HTTP 200 OK`.
- [ ] HAProxy muestra todos los backends en `UP`.
- [ ] Escrituras funcionan por puerto `3307`.
- [ ] Lecturas funcionan por puerto `3308`.
- [ ] Se demuestra caída y recuperación de un esclavo.
- [ ] Sysbench read-only se ejecuta con 8 hilos durante 60 segundos.
- [ ] Sysbench read/write se ejecuta con 8 hilos durante 60 segundos.
- [ ] Se agregan capturas del dashboard.
- [ ] Se agregan resultados de benchmarks.

---

## 31. Conclusión

El proyecto implementa una solución de balanceo de carga para bases de datos MySQL usando HAProxy en modo TCP. La arquitectura separa correctamente el tráfico de escritura y lectura, utilizando un nodo maestro para escrituras y dos esclavos para lecturas.

La replicación basada en GTID permite mantener sincronizados los esclavos con el maestro. Los health checks personalizados con xinetd permiten que HAProxy detecte automáticamente si un nodo está activo, si el maestro está disponible para escritura y si los esclavos mantienen la replicación saludable.

Finalmente, el dashboard de HAProxy y las pruebas con Sysbench permiten validar el estado del sistema, la tolerancia a fallos y el rendimiento de la arquitectura.
