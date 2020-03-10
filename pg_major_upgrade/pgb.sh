#!/bin/bash

oenv=$1
PGPORT_UNI=$2

while true
do
  env $oenv pgbench -p $PGPORT_UNI -P 5 -T 25 -c 15 -j 15
done


