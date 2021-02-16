#/bin/bash

for (( i=1; i <= 100; i++ ))
do
  psql -h 127.0.0.1 -p $2 -d regression -c "INSERT INTO t (id, pos, xid) VALUES ($1, $i, txid_current())"
done;

