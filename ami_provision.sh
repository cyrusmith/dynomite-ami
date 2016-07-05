#!/bin/bash

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

# set locales
if [ ! -f '/etc/profile.d/set_locales.sh' ]; then
sudo tee /etc/profile.d/set_locales.sh 2> 1 1> /dev/null <<EOF
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
EOF
fi

# install deps
sudo apt-get update
sudo apt-get install -y git tcl build-essential libtool libssl-dev autoconf automake

# swap on
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo "/swapfile   none    swap    sw    0   0" | sudo tee /etc/fstab 2> 1 1> /dev/null

# install java
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
sudo add-apt-repository -y ppa:webupd8team/java
sudo apt-get update
sudo apt-get install -y oracle-java8-installer
sudo apt-get install -y oracle-java8-set-default

mkdir ~/src

# install dinomitedb
cd ~/src
git clone https://github.com/Netflix/dynomite.git
cd dynomite/
autoreconf -fvi
./configure --enable-debug=log
make

sudo mkdir -p /apps/dynomite/bin
sudo cp ~/src/dynomite/src/dynomite /apps/dynomite/bin/
sudo cp ~/src/dynomite/bin/* /apps/dynomite/bin/

sudo mkdir -p /apps/dynomite/conf/
sudo tee /apps/dynomite/conf/dynomite.yml 2> 1 1> /dev/null <<EOF
dyn_o_mite:
  dyn_listen: 0.0.0.0:8101
  data_store: 0
  listen: 0.0.0.0:8102
  dyn_seed_provider: dynomitemanager_provider
  servers:
    - 127.0.0.1:22122:1
  tokens: '1383429731'
  auto_eject_hosts: true
  rack: null
  distribution: vnode
  gos_interval: 10000
  hash: murmur
  preconnect: true
  server_retry_timeout: 30000
  timeout: 5000
  secure_server_option: datacenter
  datacenter: us-west-2
  read_consistency: DC_ONE
  write_consistency: DC_ONE
  pem_key_file: /apps/dynomite/conf/dynomite.pem
EOF

sudo cp ~/src/dynomite/conf/recon_* /apps/dynomite/conf/
sudo cp ~/src/dynomite/conf/*.pem /apps/dynomite/conf/

# install redis
cd ~/src
wget http://download.redis.io/releases/redis-3.0.4.tar.gz
tar xzf redis-3.0.4.tar.gz
cd redis-3.0.4/
cd deps ; make hiredis jemalloc linenoise lua ; cd ..
make
make test
sudo make install

sudo bash utils/install_server.sh <<EOF
22122
/apps/nfredis/conf/redis.conf
/var/log/redis_22122.log
/mnt/data/nfredis/
/usr/local/bin/redis-server
EOF

rm -rf ~/src
