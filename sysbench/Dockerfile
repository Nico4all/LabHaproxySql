FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y sysbench default-mysql-client && \
    rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]