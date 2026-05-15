# HAProxy Load Balancer para MySQL - Parte 2

## Descripción

Este proyecto implementa un **balanceador de carga HAProxy** para un cluster MySQL con replicación maestro-esclavo, separando el tráfico de **escritura** (maestro) y **lectura** (esclavos).

## Arquitectura

```
┌─────────────────────────────────────────┐
│         Aplicación Cliente              │
└────────────┬─────────────────┬──────────┘
             │                 │
    Escrituras (3307)    Lecturas (3308)
             │                 │
             ▼                 ▼
    ┌─────────────────────────────────┐
    │          HAProxy                │
    │  • Escritura → Master           │
    │  • Lectura → Slaves (RR)        │
    │  • Health Checks HTTP           │
    │  • Stats Dashboard :8080        │
    └─────┬─────────────────┬─────────┘
          │                 │
    Solo Master      Round-Robin Slaves
          │                 │
          ▼          ┌──────┴──────┐
    ┌──────────┐    ▼             ▼
    │  Master  │  ┌────────┐  ┌────────┐
    │ :3306    │  │ Slave1 │  │ Slave2 │
    │ :9200    │  │ :3306  │  │ :3306  │
    └──────────┘  │ :9201  │  │ :9202  │
                  └────────┘  └────────┘
```

## 🔧 Componentes

### 1. HAProxy Frontends

#### Frontend de Escritura (puerto 3307)
- **Propósito**: Todas las operaciones INSERT, UPDATE, DELETE
- **Backend**: Solo el servidor maestro MySQL
- **Algoritmo**: N/A (un solo servidor)
- **Casos de uso**: 
  - Crear tablas
  - Insertar datos
  - Actualizar registros
  - Eliminar datos

#### Frontend de Lectura (puerto 3308)
- **Propósito**: Todas las operaciones SELECT
- **Backend**: Servidores esclavos MySQL (2 nodos)
- **Algoritmo**: Round-robin (distribución equitativa)
- **Casos de uso**:
  - Consultas SELECT
  - Reportes
  - Análisis de datos
  - Búsquedas

### 2. Health Checks HTTP

HAProxy verifica la salud de cada nodo MySQL cada 2 segundos:

#### Health Check del Maestro (puerto 9200)
```bash
GET / HTTP/1.1
```
**Respuesta esperada**: HTTP 200 OK
- ✅ MySQL está corriendo
- ❌ HTTP 503 si MySQL está caído

#### Health Check de Esclavos (puertos 9201, 9202)
```bash
GET / HTTP/1.1
```
**Respuesta esperada**: HTTP 200 OK si:
- ✅MySQL está corriendo
- ✅Replica_IO_Running = Yes
- ✅Replica_SQL_Running = Yes
- ✅Seconds_Behind_Source < 30

**Respuesta**: HTTP 503 si:
- MySQL está caído
- Thread de replicación detenido
- Lag > 30 segundos

### 3. Dashboard de Estadísticas

**URL**: http://localhost:8080/stats  
**Credenciales**: admin / admin123

**Información disponible**:
- Estado de backends (UP/DOWN)
- Número de conexiones activas
- Tráfico total procesado
- Latencias
- Health check status
- Distribución de carga

## Instalación

### Opción 1: Quick Start (Recomendada)

```bash
cd /vagrant
chmod +x scripts/quick-start-haproxy.sh
./scripts/quick-start-haproxy.sh
```

Este script hace TODO automáticamente:
1. Construye las imágenes
2. Levanta los contenedores
3. Configura la replicación
4. Verifica que todo funcione
5. Ejecuta pruebas de balanceo

### Opción 2: Manual

```bash
# 1. Levantar servicios
docker-compose up -d

# 2. Esperar 90 segundos
sleep 90

# 3. Configurar maestro
docker exec -it mysql-master mysql -uroot -prootpass123 -e "
SET GLOBAL read_only = OFF;
SET GLOBAL super_read_only = OFF;
"

# 4. Arreglar replicación
MASTER_UUID=$(docker exec mysql-master mysql -uroot -prootpass123 -s -N -e "SELECT @@server_uuid" | tr -d '\r' | tr -d ' ')

docker exec -i mysql-slave1 mysql -uroot -prootpass123 << EOF
STOP REPLICA;
SET GTID_NEXT='${MASTER_UUID}:7';
BEGIN; COMMIT;
SET GTID_NEXT='AUTOMATIC';
START REPLICA;
EOF

docker exec -i mysql-slave2 mysql -uroot -prootpass123 << EOF
STOP REPLICA;
SET GTID_NEXT='${MASTER_UUID}:7';
BEGIN; COMMIT;
SET GTID_NEXT='AUTOMATIC';
START REPLICA;
EOF

# 5. Verificar
./scripts/verify-haproxy.sh
```

## ✅ Verificación

### Verificar HAProxy
```bash
./scripts/verify-haproxy.sh
```

Salida esperada:
```
✓ HAProxy está corriendo
✓ Puerto 3307 abierto (escritura)
✓ Puerto 3308 abierto (lectura)
✓ Puerto 8080 abierto (stats)
✓ mysql-master: UP
✓ mysql-slave1: UP
✓ mysql-slave2: UP
```

### Probar Balanceo de Carga
```bash
./scripts/test-haproxy-balancing.sh
```

Este script demuestra:
1. **Escrituras van al maestro** (puerto 3307)
2. **Lecturas se balancean** entre esclavos (puerto 3308)
3. **Round-robin funciona** (~50% en cada esclavo)
4. **Puerto de lectura es read-only**

## Uso de HAProxy

### Desde la Aplicación

```python
# Python ejemplo
import mysql.connector

# Conexión para ESCRITURA (puerto 3307 → maestro)
write_conn = mysql.connector.connect(
    host='localhost',
    port=3307,
    user='root',
    password='rootpass123',
    database='testdb'
)

# Conexión para LECTURA (puerto 3308 → esclavos con round-robin)
read_conn = mysql.connector.connect(
    host='localhost',
    port=3308,
    user='root',
    password='rootpass123',
    database='testdb'
)

# ESCRITURA
cursor_write = write_conn.cursor()
cursor_write.execute("INSERT INTO users (name) VALUES ('Alice')")
write_conn.commit()

# LECTURA (balanceada entre esclavos)
cursor_read = read_conn.cursor()
cursor_read.execute("SELECT * FROM users")
results = cursor_read.fetchall()
```

### Desde MySQL CLI

```bash
# ESCRITURA (puerto 3307)
mysql -h127.0.0.1 -P3307 -uroot -prootpass123 -e "
INSERT INTO testdb.users (name) VALUES ('Bob');
"

# LECTURA (puerto 3308)
mysql -h127.0.0.1 -P3308 -uroot -prootpass123 -e "
SELECT * FROM testdb.users;
"
```

## 🔍 Monitoreo

### Dashboard Web
Accede a http://localhost:8080/stats

### Ver Logs de HAProxy
```bash
docker-compose logs -f haproxy
```

### Verificar Estado de Backends
```bash
# Via CSV API
curl -s -u admin:admin123 "http://localhost:8080/stats;csv" | grep mysql

# Via socket (desde dentro del contenedor)
docker exec haproxy sh -c 'echo "show stat" | nc localhost 8080'
```

### Métricas Clave

| Métrica | Descripción |
|---------|-------------|
| status | UP/DOWN del backend |
| scur | Sesiones actuales |
| smax | Sesiones máximas |
| stot | Total de sesiones |
| bin/bout | Bytes entrada/salida |
| dreq/dresp | Requests/responses denegadas |
| hrsp_2xx | Respuestas HTTP 2xx |

## 🛠️ Configuración Avanzada

### Ajustar Timeouts

Editar `haproxy/haproxy.cfg`:

```haproxy
defaults
    timeout connect 10s   # Tiempo para conectar al backend
    timeout client  1h    # Tiempo max de inactividad del cliente
    timeout server  1h    # Tiempo max de inactividad del servidor
    timeout check   5s    # Timeout del health check
```

### Cambiar Algoritmo de Balanceo

```haproxy
backend mysql_slaves_backend
    balance leastconn  # Opciones: roundrobin, leastconn, source
```

### Ajustar Health Checks

```haproxy
server mysql-slave1 172.20.0.11:3306 check port 9201 inter 5s rise 3 fall 2
#                                                       ^      ^      ^
#                                                       |      |      |
#                                      Intervalo (5s) --+      |      |
#                                      Checks OK para UP ------+      |
#                                      Checks FAIL para DOWN ---------+
```

### Sticky Sessions (Opcional)

Si necesitas que un cliente siempre vaya al mismo esclavo:

```haproxy
backend mysql_slaves_backend
    balance source  # Basado en IP del cliente
```

## Troubleshooting

### Problema: HAProxy no inicia

```bash
# Ver logs
docker-compose logs haproxy

# Verificar sintaxis de configuración
docker exec haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
```

### Problema: Backends aparecen como DOWN

```bash
# Verificar health checks manualmente
curl -i http://localhost:9200  # Master
curl -i http://localhost:9201  # Slave 1
curl -i http://localhost:9202  # Slave 2

# Verificar replicación
./scripts/verify-replication.sh
```

### Problema: Conexión rechazada al puerto 3307/3308

```bash
# Verificar que HAProxy esté escuchando
docker exec haproxy netstat -tlnp | grep -E '3307|3308'

# Verificar firewall de la VM
sudo ufw status
```

### Problema: Lecturas no se balancean

```bash
# Verificar algoritmo de balance
docker exec haproxy grep -A5 "mysql_slaves_backend" /usr/local/etc/haproxy/haproxy.cfg

# Ver distribución en tiempo real
watch -n1 'curl -s -u admin:admin123 "http://localhost:8080/stats;csv" | grep mysql-slave | cut -d, -f1,2,18,33'
```

## Escalabilidad

### Agregar más esclavos

1. Editar `docker-compose.yml`:
```yaml
mysql-slave3:
  build:
    context: ./mysql
  environment:
    MYSQL_SERVER_ID: 4
  networks:
    mysql-network:
      ipv4_address: 172.20.0.13
```

2. Editar `haproxy/haproxy.cfg`:
```haproxy
backend mysql_slaves_backend
    server mysql-slave3 172.20.0.13:3306 check port 9203 inter 2s
```

3. Reconstruir:
```bash
docker-compose up -d --build
```

## Seguridad

### Cambiar Credenciales del Dashboard

Editar `haproxy/haproxy.cfg`:
```haproxy
listen stats
    stats auth admin:TU_NUEVA_CONTRASEÑA_AQUI
```

### Restringir Acceso al Dashboard

```haproxy
listen stats
    bind 127.0.0.1:8080  # Solo localhost
    # o
    acl allowed_ips src 192.168.56.0/24
    http-request deny unless allowed_ips
```

## Referencias

- [HAProxy Documentation](http://www.haproxy.org/download/2.8/doc/configuration.txt)
- [MySQL Replication](https://dev.mysql.com/doc/refman/8.0/en/replication.html)
- [HAProxy Best Practices](https://www.haproxy.com/blog/haproxy-best-practices/)

