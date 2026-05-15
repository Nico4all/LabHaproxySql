#!/bin/bash
#
# Servidor HTTP simple para health checks usando socat
# Escucha en el puerto 9200 y ejecuta el health check
#

PORT=9200
HEALTH_CHECK_SCRIPT="/usr/local/bin/healthcheck.sh"

echo "Iniciando servidor HTTP de health check en puerto $PORT..."

# Loop infinito que escucha conexiones y ejecuta el health check
while true; do
    socat TCP-LISTEN:$PORT,bind=0.0.0.0,reuseaddr,fork EXEC:"$HEALTH_CHECK_SCRIPT" 2>/dev/null
    
    # Si socat falla, esperar un segundo y reintentar
    sleep 1
done
