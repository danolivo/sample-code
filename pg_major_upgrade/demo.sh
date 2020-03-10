# ##############################################################################
#
# Upgrading from PG 11 to PG12 with Logical Replication.
# URL: https://www.2ndquadrant.com/en/blog/upgrading-to-postgresql-11-with-logical-replication/
#
# ##############################################################################

U=`whoami`
old=std11
new=std12

rm pgbouncer.log
PGPORT_ROOT=5433
PGPORT_LEAF=5434
PGPORT_UNI=6432

pkill -9 -U $U -e postgres
pkill -9 -U $U -e pgbouncer
pkill -9 -U $U -e pgb.sh
sed -i -r 's/port=5434/port=5433/g' pgbouncer.ini;

echo "Compile & launch instances"
cd $old && ../pre $PGPORT_ROOT
echo "Root takeoff"

cd ../$new && ../pre $PGPORT_LEAF
echo "Leaf takeoff"
cd ../

old_bin=$old/tmp_install/bin
old_lib=$old/tmp_install/lib
new_bin=$new/tmp_install/bin
new_lib=$new/tmp_install/lib
oenv="PATH=$old_bin LD_LIBRARY_PATH=$old_lib"
nenv="PATH=$new_bin LD_LIBRARY_PATH=$new_lib"

# Initialize database and proxy
env $oenv createdb -p $PGPORT_ROOT $U
env $oenv pgbench -p $PGPORT_ROOT -i -s 10
pgbouncer/pgbouncer -d pgbouncer.ini

# Create DBMS synthetic load
./pgb.sh "$oenv" "$PGPORT_UNI" &
sleep 10

# Dump & restore the schema. ALL DDL must be forbidden before
env $oenv pg_dumpall -p $PGPORT_ROOT -s > dump.sql
echo "The schema dump was done."
env $nenv psql -p $PGPORT_LEAF postgres -f dump.sql > /dev/null
echo "The schema creation in new instance was done."

# Set logical replication
env $oenv psql -p $PGPORT_ROOT $U -c \
  "CREATE PUBLICATION p_upgrade FOR ALL TABLES;"
env $nenv psql -p $PGPORT_LEAF $U -c \
  "CREATE SUBSCRIPTION s_upgrade CONNECTION 'port=$PGPORT_ROOT dbname=$U'
  PUBLICATION p_upgrade;"

# Wait until the subscriptions have copied over the initial data and have fully
# caught up with the publisher.
while true
do
  SubsInitFinished=$(env $nenv psql -p $PGPORT_LEAF $U -qtc \
    "SELECT * FROM pg_subscription_rel WHERE srsubstate <> 'r';")

  if [ -z "$SubsInitFinished" ]; then
    echo "Subscription initialization finished"
    break
  fi
  echo "Wait for subscription initialization..."
  sleep 5
done

# Wait pgbench is loading the DBMS
sleep 15

# Wait until the leaf minimizes difference with the root
while true
do
  res=$(env $oenv psql -p $PGPORT_ROOT $U -qtc \
    "SELECT sent_lsn,write_lsn FROM pg_stat_replication WHERE application_name = 's_upgrade';")
  echo "sent_lsn,write_lsn = $res"

  diff_lsn=$(env $oenv psql -p $PGPORT_ROOT $U -qtc \
    "SELECT pg_wal_lsn_diff(sent_lsn, write_lsn) FROM pg_stat_replication;")

  echo "diff_lsn: $diff_lsn"

  if [ $diff_lsn -lt 1000 ]; then
    echo "Difference between the root and the leaf was minimized"
    break
  fi
  echo "Wait..."
  sleep 5
done

# Switch to the upgraded server
env $oenv psql -p 6432 -d pgbouncer -c "PAUSE;" # Wait until all transactions will be finished
sed -i -r 's/port=5433/port=5434/g' pgbouncer.ini;
env $oenv psql -p 6432 -d pgbouncer -c "RELOAD;"

# Wait for the end of sync via the logical replication slot.
while true
do
  diff_lsn=$(env $oenv psql -p $PGPORT_ROOT $U -qtc \
    "SELECT pg_wal_lsn_diff(sent_lsn, write_lsn) FROM pg_stat_replication
    WHERE application_name = 's_upgrade';" | awk '{print $1}')
  
  if [ $diff_lsn -eq 0 ]; then
    echo "Root and leaf was synchronized"
    break
  fi
  echo "Wait... diff_lsn: $diff_lsn"
  sleep 5
done

while true
do
  diff_lsn=$(env $oenv psql -p $PGPORT_ROOT $U -qtc \
    "SELECT pg_wal_lsn_diff(sent_lsn, write_lsn) from pg_stat_replication
    WHERE application_name = 's_upgrade';")

  if [ $diff_lsn -eq 0 ]; then
    echo "Replica was restored fully"
    break
  fi
  echo "Wait for replication..."
done

# Promote replica...
env $nenv psql -p $PGPORT_LEAF $U -c "DROP SUBSCRIPTION s_upgrade;"
env $oenv psql -p 6432 -d pgbouncer -c "RESUME;"
env $oenv pg_ctl -D $old/PGDATA stop

# For demonstration purposes only
sleep 50

# Stop everything
pkill -9 -e -U $U pgb.sh
env $oenv psql -p 6432 -d pgbouncer -c "SHUTDOWN;"
env $oenv pg_ctl -D $new/PGDATA stop
rm dump.sql
