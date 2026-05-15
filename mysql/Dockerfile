FROM mysql:8.0

# Instalar socat para el servidor HTTP del health check
# MySQL 8.0 usa Oracle Linux, que usa microdnf
RUN microdnf install -y socat procps-ng && \
    microdnf clean all

# Copiar script de health check
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

# Copiar servidor HTTP para health check
COPY health-server.sh /usr/local/bin/health-server.sh
RUN chmod +x /usr/local/bin/health-server.sh

# Copiar script de entrada personalizado
COPY docker-entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

# Copiar configuraciones de MySQL
COPY mysql-master.cnf /etc/mysql/conf.d/mysql-master.cnf
COPY mysql-slave.cnf /etc/mysql/conf.d/mysql-slave.cnf

# Arreglar permisos de los archivos de configuración
RUN chmod 644 /etc/mysql/conf.d/mysql-master.cnf && \
    chmod 644 /etc/mysql/conf.d/mysql-slave.cnf

ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
CMD ["mysqld"]
