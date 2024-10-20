#!/bin/bash

app_path="/home/ubuntu/app"
log_path="/tmp/kafka-logs"

mkdir -p "$app_path"
mkdir -p "$log_path"
cd "$app_path"
wget https://downloads.apache.org/kafka/3.8.0/kafka_2.12-3.8.0.tgz
tar -zxf kafka_*.tgz
rm kafka_*.tgz
ln -Tfs kafka_* kafka
