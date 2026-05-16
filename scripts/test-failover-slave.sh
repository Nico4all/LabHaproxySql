#!/bin/bash

echo "=== Estado inicial HAProxy ==="
curl -s -u admin:admin123 "http://localhost:8080/stats;csv" | grep mysql-slave

echo ""
echo "=== Deteniendo mysql-slave1 ==="
docker compose stop mysql-slave1

echo "Esperando detección..."
sleep 10

echo ""
echo "=== Estado después de caída ==="
curl -s -u admin:admin123 "http://localhost:8080/stats;csv" | grep mysql-slave

echo ""
echo "=== Levantando mysql-slave1 otra vez ==="
docker compose start mysql-slave1

echo "Esperando redetección..."
sleep 20

echo ""
echo "=== Estado final ==="
curl -s -u admin:admin123 "http://localhost:8080/stats;csv" | grep mysql-slave