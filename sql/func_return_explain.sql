CREATE TABLE IF NOT EXISTS a (x int);
CREATE INDEX ON a(x);
CREATE TABLE IF NOT EXISTS b (t text);
INSERT INTO b VALUES ('PREPARE stmt (int, int) AS SELECT count(*) FROM a WHERE x = 1 OR (x > $2 AND x < $1) OR x = $1');
ANALYZE;

CREATE OR REPLACE FUNCTION testfn() RETURNS SETOF text AS $$
DECLARE
	t1 text;
BEGIN
	SET plan_cache_mode = 'force_generic_plan';
	SET enable_seqscan = 'off';
	
	SELECT t FROM b INTO t1;
	execute t1;

	RETURN QUERY EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF)
		EXECUTE stmt(15,12);
	RETURN;
END;
$$ LANGUAGE PLPGSQL;

SELECT testfn();

DROP FUNCTION testfn;
DROP TABLE a,b;
