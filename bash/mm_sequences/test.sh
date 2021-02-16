#!/bin/bash

srv1str="-h 127.0.0.1 -p 65432 -d regression"
srv2str="-h 127.0.0.1 -p 65433 -d regression"

psql $srvstr -c "
	DROP SEQUENCE IF EXISTS test_seq;
	DROP TABLE IF EXISTS t CASCADE;
	CREATE TABLE t (id int, value serial, pos int, data timestamp DEFAULT CURRENT_TIMESTAMP, xid bigint);
	CREATE UNIQUE INDEX ON t(value);
"

./scr1.sh 1 65432 &
./scr1.sh 2 65433

psql $srv1str -c "SHOW multimaster.monotonic_sequences;"
psql $srv1str -c "CREATE SEQUENCE test_seq;"

for (( i=1; i <= 5; i++ ))
do
  psql $srv1str -c "SELECT nextval('test_seq')"
done;

psql $srv2str -c "SELECT nextval('test_seq')"
psql $srv2str -c "SELECT nextval('test_seq')"
