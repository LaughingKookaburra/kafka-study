#!/bin/bash

if [ $# -ne 1 ]
then 
  echo "usage: $0 topic" 
  exit 1
fi

topic=$1

/home/ubuntu/app/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --create --replication-factor 1 --partitions 1 --topic $topic
/home/ubuntu/app/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic $topic