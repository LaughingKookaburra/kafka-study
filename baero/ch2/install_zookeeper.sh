#!/bin/bash

app_path="/home/ubuntu/app"
config_file_path="${app_path}/zookeeper/conf"
config_file_name="zoo.cfg"
data_dir="/var/lib/zookeeper"

mkdir -p "$app_path"
cd "$app_path"
wget https://dlcdn.apache.org/zookeeper/zookeeper-3.9.2/apache-zookeeper-3.9.2-bin.tar.gz
tar -zxf apache-zookeeper-*.tar.gz
rm apache-zookeeper-*.tar.gz
ln -Tfs apache-zookeeper-* zookeeper

mkdir -p "$config_file_path"
cd "$config_file_path"
cat << EOF > "$config_file_name"
tickTime=2000
dataDir="$data_dir"
clientPort=2181
EOF

mkdir -p "$data_dir"

echo "Run command: `${app_path}/zookeeper/bin/zkServer.sh start`"