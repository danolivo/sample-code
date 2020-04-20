#!/bin/bash

pre
pgbench -i -s 5
pgbench -c 2 -j 1 -P 1 -T 3000 --restore-conn=1000 &

PGDATA=`pwd`/PGDATA
timeout=0
tstart=$(date +"%s")
tend=0

echo "$tstart"

while [ $((tend-tstart)) -le 1000 ]
do
  let "timeout = $RANDOM % 10"
  tend=$(date +"%s")
  echo "timeout: $timeout"
  sleep $timeout
  pg_ctl -D $PGDATA -l logfile.log restart
done
