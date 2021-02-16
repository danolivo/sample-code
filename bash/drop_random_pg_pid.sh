#!/bin/bash

result=$(psql -t -p $1 -h localhost -c "select pid from pg_stat_activity")
pids=$(echo "$result" | awk 'END{print NR}')
let "number=$RANDOM%$pids"

pid=$(echo "$result" | awk -v var="$number" 'BEGIN{x=1}; {if (x == var)print $1; x++}')

if [[ "$pid" -ne "" ]]; then
	echo "DELETE $pid"
	kill -9 $pid
else
	echo "Node on port $1 is not responding"
fi
