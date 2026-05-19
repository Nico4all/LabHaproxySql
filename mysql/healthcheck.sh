#!/bin/bash

MYSQL_HOST_CHECK="127.0.0.1"
MYSQL_USER_CHECK="root"
MYSQL_PASS_CHECK="${MYSQL_ROOT_PASSWORD}"

send_ok() {
    printf "HTTP/1.1 200 OK\r\n"
    printf "Content-Type: text/plain\r\n"
    printf "Connection: close\r\n"
    printf "\r\n"
    printf "OK - %s\n" "$1"
    exit 0
}

send_fail() {
    printf "HTTP/1.1 503 Service Unavailable\r\n"
    printf "Content-Type: text/plain\r\n"
    printf "Connection: close\r\n"
    printf "\r\n"
    printf "FAIL - %s\n" "$1"
    exit 1
}

mysqladmin ping \
    -h"${MYSQL_HOST_CHECK}" \
    -u"${MYSQL_USER_CHECK}" \
    -p"${MYSQL_PASS_CHECK}" \
    --silent > /dev/null 2>&1

if [ $? -ne 0 ]; then
    send_fail "MySQL is not running"
fi

ROLE="${MYSQL_ROLE:-unknown}"

if [ "$ROLE" = "master" ]; then
    READ_ONLY=$(mysql \
        -h"${MYSQL_HOST_CHECK}" \
        -u"${MYSQL_USER_CHECK}" \
        -p"${MYSQL_PASS_CHECK}" \
        -Nse "SELECT @@read_only;" 2>/dev/null)

    if [ "$READ_ONLY" = "0" ]; then
        send_ok "Master is writable"
    else
        send_fail "Master is read-only"
    fi
fi

if [ "$ROLE" = "slave" ]; then
    REPLICA_STATUS=$(mysql \
        -h"${MYSQL_HOST_CHECK}" \
        -u"${MYSQL_USER_CHECK}" \
        -p"${MYSQL_PASS_CHECK}" \
        -e "SHOW REPLICA STATUS\G" 2>/dev/null)

    IO_RUNNING=$(echo "$REPLICA_STATUS" | grep "Replica_IO_Running:" | awk '{print $2}')
    SQL_RUNNING=$(echo "$REPLICA_STATUS" | grep "Replica_SQL_Running:" | awk '{print $2}')
    SECONDS_BEHIND=$(echo "$REPLICA_STATUS" | grep "Seconds_Behind_Source:" | awk '{print $2}')

    if [ "$IO_RUNNING" = "Yes" ] && [ "$SQL_RUNNING" = "Yes" ]; then
        send_ok "Slave replication healthy. Lag=${SECONDS_BEHIND}"
    else
        send_fail "Slave replication not healthy"
    fi
fi

send_fail "Unknown role: ${ROLE}"