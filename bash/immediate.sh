#!/bin/bash

# ##############################################################################
#
# Recovery test for node 1
#
# Nodes configuration:
# node1 host: default, db: default, user: default, port: 5432
# node2: host: default, db: default, user: default, port: 5433
# referee: host: default, db: default, user: default, port: 5434
#
# ##############################################################################

pgbench -p 5432 -i -s 10

while [ true ]
do
  txid_n1=$(psql -p 5432 -qtc "SELECT * FROM txid_current();")
  txid_n2=$(psql -p 5433 -qtc "SELECT * FROM txid_current();")

  pgbench -p 5432 -T 100 -c 2 -j 2 &
  echo "pgbench to node1 started"
  sleep 1

  pgbench -p 5433 -T 100 -c 2 -j 2 &
  echo "pgbench to node2 started"
  sleep 10
  
  pg_ctl restart -D PGDATA1 -m immediate -l logfile_1.log
  wait_iters_max=0
  RES1=$(psql -p 5432 -qtc "SELECT status FROM mtm.status();")
  RES2=$(psql -p 5433 -qtc "SELECT status FROM mtm.status();")
  
  while [[ -z $RES1 || $RES1 != " online" || -z $RES2 || $RES2 != " online" ]]; do
	wait_iters_max=$((wait_iters_max + 1))
	if (( wait_iters_max == 1000 ))
	then
		echo "Error. Max wait iterations was exceeded: $wait_iters_max "
		exit
	fi

	if  [[ -n $RES1 && $RES1 = " online" ]]; then
	  echo "Node1 online!"
	fi
	if  [[ -n $RES2 && $RES2 = " online" ]]; then
	  echo "Node2 online!"
	fi
	sleep 1
	
	RES1=$(psql -p 5432 -qtc "SELECT status FROM mtm.status();")
	RES2=$(psql -p 5433 -qtc "SELECT status FROM mtm.status();")
  done
  
  echo "Iteration passed"
  echo "-----------------------------------------------------------------------"
  txid_n1_1=$(psql -p 5432 -qtc "SELECT * FROM txid_current();")
  txid_n2_1=$(psql -p 5433 -qtc "SELECT * FROM txid_current();")
  echo "DTx1 = $((txid_n1_1 - txid_n1)) DTx2 = $((txid_n2_1 - txid_n2))"
done
