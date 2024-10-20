#!/bin/bash

if [ $# -ne 1 ]
then 
  echo "usage: $0 topic" 
  exit 1
fi

topic=$1

/home/ubuntu/app/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic topic --from-beginning
