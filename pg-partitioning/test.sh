#!/bin/bash

# ##############################################################################
#
# Test on problems of multipartitioned table with BRIN index
#
# ##############################################################################

. paths.sh
pre_ds
psql -f init.sql
psql -c "VACUUM;"
iter=1
for (( YEAR=2021; YEAR<2030; YEAR++ ))
do
	for (( MONTH=1; MONTH<=12; MONTH++ ))
	do
		psql -c "
			CREATE TABLE d_1_$iter PARTITION OF d_1 (time)
				FOR VALUES FROM ('$YEAR-$MONTH-01 00:00:00') TO ('$YEAR-$MONTH-28 23:59:59')
				WITH (FILLFACTOR=95, autovacuum_analyze_threshold=0);
			CREATE TABLE d_2_$iter PARTITION OF d_2 (time)
				FOR VALUES FROM ('$YEAR-$MONTH-01 00:00:00') TO ('$YEAR-$MONTH-28 23:59:59')
				WITH (FILLFACTOR=95, autovacuum_analyze_threshold=0);
			CREATE TABLE d_3_$iter PARTITION OF d_3 (time)
				FOR VALUES FROM ('$YEAR-$MONTH-01 00:00:00') TO ('$YEAR-$MONTH-28 23:59:59')
				WITH (FILLFACTOR=95, autovacuum_analyze_threshold=0);
			CREATE TABLE d_4_$iter PARTITION OF d_4 (time)
				FOR VALUES FROM ('$YEAR-$MONTH-01 00:00:00') TO ('$YEAR-$MONTH-28 23:59:59')
				WITH (FILLFACTOR=95, autovacuum_analyze_threshold=0);
		"
		psql -c "CREATE INDEX ON d_1_$iter USING brin (time) WITH (pages_per_range=4,autosummarize=true);"
		psql -c "CREATE INDEX ON d_2_$iter USING brin (time) WITH (pages_per_range=4,autosummarize=true);"
		psql -c "CREATE INDEX ON d_3_$iter USING brin (time) WITH (pages_per_range=4,autosummarize=true);"
		psql -c "CREATE INDEX ON d_4_$iter USING brin (time) WITH (pages_per_range=4,autosummarize=true);"

		./month_events.sh $YEAR $MONTH $iter
#		sleep 10
		iter=$((iter + 1))
		pkill -9 -e month_events.sh
	done
done
