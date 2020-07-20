#!/bin/bash

# ##############################################################################
#
# Generate data for a month.
#
# ##############################################################################

YEAR=$1
MONTH=$2
iter=$3

RANGE=100
for (( i = 0; i < 1000; i++ ))
do
	query="INSERT INTO d (id, time, pld) SELECT random()*10000, timestamp '$YEAR-$MONTH-01 00:00:00' + \
	random() * (timestamp '$YEAR-$MONTH-28 23:59:59' - timestamp '$YEAR-$MONTH-01 00:00:00'), 'abc' || '$iter' FROM generate_series(1,100);"
	psql -c "$query"
	
	number=$RANDOM
	let "number %= $RANGE"
	
	if [[ $number -lt 50 ]]
	then
		num=$RANDOM
		let "num %= 10000"
		psql -c "SELECT * FROM d_1_$iter WHERE id = $num;" >> /dev/null
		psql -c "SELECT * FROM d_2_$iter WHERE id = $num;" >> /dev/null
		psql -c "SELECT * FROM d_3_$iter WHERE id = $num;" >> /dev/null
		psql -c "SELECT * FROM d_4_$iter WHERE id = $num;" >> /dev/null
	fi 
	
	if [[ "$number" -lt "2" ]]
	then
		num=$RANDOM
		let "num %= 9950"
		psql -c "
			BEGIN;
			SELECT NULL FROM d_1_$iter WHERE id > $num AND id < $num+50;
			DELETE FROM d_1_$iter WHERE id > $num AND id < $num+50;
			END;
		"
		psql -c "
			BEGIN;
			SELECT NULL FROM d_2_$iter WHERE id > $num AND id < $num+50;
			DELETE FROM d_2_$iter WHERE id > $num AND id < $num+50;
			END;
		"
		psql -c "
			BEGIN;
			SELECT NULL FROM d_3_$iter WHERE id > $num AND id < $num+50;
			DELETE FROM d_3_$iter WHERE id > $num AND id < $num+50;
			END;
		"
		psql -c "
			BEGIN;
			SELECT NULL FROM d_4_$iter WHERE id > $num AND id < $num+50;
			DELETE FROM d_4_$iter WHERE id > $num AND id < $num+50;
			END;
		"
	fi  

	if [[ "$number" -lt "20" ]]
	then
		num=$RANDOM
		let "num %= 9950"
		psql -c "
			BEGIN;
			SELECT NULL FROM d_1_$iter WHERE id > $num AND id < $num+50;
			UPDATE d_1_$iter SET id = id + 1 WHERE id > $num AND id < $num+50;
			END;
		"
		psql -c "
			BEGIN;
			SELECT NULL FROM d_2_$iter WHERE id > $num AND id < $num+50;
			UPDATE d_2_$iter SET id = id + 1 WHERE id > $num AND id < $num+50;
			END;
		"
		psql -c "
			BEGIN;
			SELECT NULL FROM d_3_$iter WHERE id > $num AND id < $num+50;
			UPDATE d_3_$iter SET id = id + 1 WHERE id > $num AND id < $num+50;
			END;
		"
		psql -c "
			BEGIN;
			SELECT NULL FROM d_4_$iter WHERE id > $num AND id < $num+50;
			UPDATE d_4_$iter SET id = id + 1 WHERE id > $num AND id < $num+50;
			END;
		"
	fi
done
