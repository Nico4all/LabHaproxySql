
#!/bin/bash
#
# Script de inicio rápido para el proyecto
#

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  MySQL Load Balancer con HAProxy - Inicio Rápido         ║"
echo "║  Parte 1: Replicación MySQL                               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Verificar que estamos en la VM
if [ ! -f "/vagrant/.env" ]; then
    echo "❌ Error: Este script debe ejecutarse dentro de la VM Vagrant"
    echo "   Por favor ejecuta: vagrant ssh"
    exit 1
fi

cd /vagrant

echo "📋 Paso 1: Verificando Docker..."
if ! docker --version &> /dev/null; then
    echo "❌ Docker no está instalado"
    exit 1
fi
echo "✅ Docker está instalado"
echo ""

echo "📦 Paso 2: Construyendo imágenes Docker..."
docker-compose build
echo "✅ Imágenes construidas"
echo ""

echo "🚀 Paso 3: Levantando contenedores..."
docker-compose up -d
echo "✅ Contenedores iniciados"
echo ""

echo "⏳ Paso 4: Esperando que MySQL esté listo (60 segundos)..."
sleep 60
echo ""

echo "🔍 Paso 5: Verificando estado de contenedores..."
docker-compose ps
echo ""

echo "✅ Paso 6: Verificando replicación MySQL..."
chmod +x scripts/verify-replication.sh
./scripts/verify-replication.sh
echo ""

echo "✅ Paso 7: Verificando health checks..."
chmod +x scripts/verify-healthchecks.sh
./scripts/verify-healthchecks.sh
echo ""

echo "🧪 Paso 8: Ejecutando prueba de replicación..."
chmod +x scripts/test-replication.sh
./scripts/test-replication.sh
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ✅ INSTALACIÓN COMPLETADA EXITOSAMENTE                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Servicios disponibles:"
echo "   • MySQL Master:    localhost:3306  (Health: localhost:9200)"
echo "   • MySQL Slave 1:   localhost:3316  (Health: localhost:9201)"
echo "   • MySQL Slave 2:   localhost:3326  (Health: localhost:9202)"
echo ""
echo "🔧 Comandos útiles:"
echo "   docker-compose ps              # Ver estado de contenedores"
echo "   docker-compose logs -f         # Ver logs en tiempo real"
echo "   ./scripts/verify-replication.sh   # Verificar replicación"
echo "   ./scripts/verify-healthchecks.sh  # Verificar health checks"
echo ""
echo "📖 Lee el README.md para más información"
echo ""