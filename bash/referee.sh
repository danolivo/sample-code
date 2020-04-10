#!/bin/bash

# ##############################################################################
#
# Launch the PostgreSQL Multimaster in the 2+1 configuration (with referee).
#
# ##############################################################################

ulimit -c unlimited

M1=`pwd`/PGDATA1
M2=`pwd`/PGDATA2
Mr=`pwd`/REFEREE
U=`whoami`

pkill -U $U -9 -e postgres
rm -rf $M1 || true
mkdir $M1
rm -rf $M2 || true
mkdir $M2
rm -rf $Mr || true
mkdir $Mr
rm -rf logfile_1.log || true
rm -rf logfile_2.log || true
rm -rf logfile_r.log || true

INSTDIR=`pwd`/tmp_install
export LD_LIBRARY_PATH=$INSTDIR/lib:$LD_LIBRARY_PATH
export PATH=$INSTDIR/bin:$PATH
export PGPORT=5432
export PGDATABASE=$U

mk

initdb -D $M1
initdb -D $M2
initdb -D $Mr

echo "shared_preload_libraries = 'multimaster, pg_pathman'" >> $M1/postgresql.conf
echo "wal_level = logical" >> $M1/postgresql.conf
echo "listen_addresses = '*'" >> $M1/postgresql.conf
echo "max_connections = 50" >> $M1/postgresql.conf
echo "max_prepared_transactions = 250" >> $M1/postgresql.conf
echo "max_worker_processes = 170" >> $M1/postgresql.conf
echo "max_wal_senders = 6" >> $M1/postgresql.conf
echo "max_replication_slots = 12" >> $M1/postgresql.conf
echo "wal_sender_timeout = 0" >> $M1/postgresql.conf
echo "multimaster.heartbeat_send_timeout = 100" >> $M1/postgresql.conf
echo "multimaster.heartbeat_recv_timeout = 5000" >> $M1/postgresql.conf
echo "multimaster.referee_connstring = 'dbname=$U user=$U port=5434'" >> $M1/postgresql.conf

echo "shared_preload_libraries = 'multimaster, pg_pathman'" >> $M2/postgresql.conf
echo "wal_level = logical" >> $M2/postgresql.conf
echo "listen_addresses = '*'" >> $M2/postgresql.conf
echo "max_connections = 50" >> $M2/postgresql.conf
echo "max_prepared_transactions = 250" >> $M2/postgresql.conf
echo "max_worker_processes = 170" >> $M2/postgresql.conf
echo "max_wal_senders = 6" >> $M2/postgresql.conf
echo "max_replication_slots = 12" >> $M2/postgresql.conf
echo "wal_sender_timeout = 0" >> $M2/postgresql.conf
echo "multimaster.heartbeat_send_timeout = 100" >> $M2/postgresql.conf
echo "multimaster.heartbeat_recv_timeout = 5000" >> $M2/postgresql.conf
echo "multimaster.referee_connstring = 'dbname=$U user=$U port=5434'" >> $M2/postgresql.conf

pg_ctl -o "-p 5432" -w -D $M1 -l logfile_1.log start
pg_ctl -o "-p 5433" -w -D $M2 -l logfile_2.log start
pg_ctl -o "-p 5434" -w -D $Mr -l logfile_r.log start

createdb -p 5432 $U
createdb -p 5433 $U
createdb -p 5434 $U

psql -p 5432 -c "CREATE EXTENSION multimaster;"
psql -p 5433 -c "CREATE EXTENSION multimaster;"
psql -p 5434 -c "CREATE EXTENSION referee;"

psql -p 5432 -c "select mtm.init_cluster('dbname=$U user=$U port=5432', '{\"dbname=$U user=$U port=5433\"}')"

RES=$(psql -qtc "SELECT status FROM mtm.status();")
wait_iters_max=0
while [[ -z $RES || $RES != " online" ]]; do
	
	wait_iters_max=$((wait_iters_max + 1))
	
	if (( wait_iters_max == 100 ))
	then
		echo "Error. Max wait iterations was exceeded: $wait_iters_max "
		exit
	fi
	
	sleep 1
	RES=$(psql -qtc "SELECT status FROM mtm.status();")
done

