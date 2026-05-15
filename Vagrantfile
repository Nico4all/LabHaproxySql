Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  
  # Configuración de la VM
  config.vm.hostname = "mysql-haproxy-lb"
  
  # Configurar red privada
  config.vm.network "private_network", ip: "192.168.56.10"
  
  # Exponer puertos necesarios al host
  # HAProxy Dashboard
  config.vm.network "forwarded_port", guest: 8080, host: 8080, host_ip: "127.0.0.1"
  # HAProxy MySQL Write (maestro)
  config.vm.network "forwarded_port", guest: 3307, host: 3307, host_ip: "127.0.0.1"
  # HAProxy MySQL Read (esclavos)
  config.vm.network "forwarded_port", guest: 3308, host: 3308, host_ip: "127.0.0.1"
  # MySQL directo del maestro (para debugging)
  config.vm.network "forwarded_port", guest: 3306, host: 3306, host_ip: "127.0.0.1"
  
  # Configuración de recursos
  config.vm.provider "virtualbox" do |vb|
    vb.name = "mysql-haproxy-loadbalancer"
    vb.memory = "4096"
    vb.cpus = 2
  end
  
  # Sincronizar carpeta del proyecto
  config.vm.synced_folder ".", "/vagrant"
  
  # Provisionar con script
  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    
    # Instalar Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Instalar Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Agregar usuario vagrant al grupo docker
    usermod -aG docker vagrant
    
    # Habilitar Docker al inicio
    systemctl enable docker
    systemctl start docker
    
    # Instalar herramientas útiles
    apt-get install -y mysql-client vim htop net-tools
    
    echo "================================="
    echo "Vagrant VM configurada exitosamente"
    echo "Docker version: $(docker --version)"
    echo "Docker Compose version: $(docker-compose --version)"
    echo "================================="
  SHELL
end