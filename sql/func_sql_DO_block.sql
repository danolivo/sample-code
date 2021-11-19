CREATE OR REPLACE FUNCTION cnt() RETURNS integer AS '
  SELECT sum(abalance) FROM pgbench_accounts;
' LANGUAGE SQL PARALLEL SAFE COST 100000.;

START TRANSACTION ISOLATION LEVEL REPEATABLE READ;

EXPLAIN VERBOSE
	SELECT count(*) AS res FROM (
		SELECT cnt() AS y FROM pgbench_accounts WHERE aid < 20
		GROUP BY (y)
	) AS q;

DO $$
DECLARE
	res integer;
BEGIN
	SELECT count(*) AS res FROM (
		SELECT cnt() AS y FROM pgbench_accounts WHERE aid < 20
		GROUP BY (y)
	) AS q INTO res;
	
	IF (res <> 1) THEN
		RAISE EXCEPTION 'RESULT: %', res;
	END IF;
END;
$$;
END;

