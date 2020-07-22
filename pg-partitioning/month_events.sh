#!/bin/bash

# ##############################################################################
#
# Generate data for a month.
#
# ##############################################################################

YEAR=$1
MONTH=$2
iter=$3

for (( i = 0; i < 100000; i++ ))
do
	number=$RANDOM
	let "number %= 100"
	
	oid=$RANDOM
	let "oid %= 10000"

	psql -c "
		INSERT INTO d (id, time, pld) (SELECT $oid, timestamp '$YEAR-$MONTH-01 00:00:00' + \
		($i / 100000.)::real * (timestamp '$YEAR-$MONTH-28 23:59:59' - timestamp '$YEAR-$MONTH-01 00:00:00'), 'abc') \
		ON CONFLICT (id, time) DO UPDATE SET pld='excluded';
	"
	
	if [[ $number -lt 20 ]]
	then
		psql -c "
			INSERT INTO d (id, time, pld) (SELECT $oid, timestamp '$YEAR-$MONTH-01 00:00:00' + \
			($i / 100000.)::real * (timestamp '$YEAR-$MONTH-28 23:59:59' - timestamp '$YEAR-$MONTH-01 00:00:00'), 'abc') \
			ON CONFLICT (id, time) DO UPDATE SET pld='excluded';
		"
	fi
done
