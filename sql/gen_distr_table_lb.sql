\set VERBOSITY terse
DROP TABLE IF EXISTS partitioned.f CASCADE;
DROP FUNCTION IF EXISTS gen_parts_tbl_lb;


CREATE OR REPLACE FUNCTION gen_parts_tbl_lb(parts integer, tblname text)
RETURNS void AS $$
DECLARE
	i integer;
	sql text;
	search_path text;
BEGIN
	execute 'SHOW search_path' INTO search_path;
	execute 'SET search_path TO partitioned,public';

	execute format('CREATE TABLE %I(a int, b int) PARTITION BY HASH (a)', tblname);

	FOR i IN 1..parts
	LOOP
		execute format('CREATE TABLE partitioned.%I%s PARTITION OF %I FOR VALUES WITH ( MODULUS %s, REMAINDER %s)',
					tblname,i,tblname,parts,i-1);
	END LOOP;

	execute format('SET search_path TO %s', search_path);
    
END $$ LANGUAGE plpgsql;


DROP SCHEMA IF EXISTS partitioned CASCADE;
CREATE SCHEMA partitioned;

-- Create partitioned table.
SELECT * FROM  gen_parts_tbl_lb(1000, 'f'::text);
SELECT * FROM  gen_parts_tbl_lb(100, 'l'::text);
SELECT * FROM  gen_parts_tbl_lb(10, 's'::text);

\echo 'INSERT ...'
INSERT INTO partitioned.f (a,b) (SELECT gs.*, -gs.* FROM generate_series(1,1000) AS gs);
INSERT INTO partitioned.l (a,b) (SELECT -gs.*, -gs.* FROM generate_series(1,10) AS gs);
INSERT INTO partitioned.s (a,b) (SELECT gs.*, -gs.* FROM generate_series(1,10) AS gs);

\echo 'ANALYZE ...'
ANALYZE;
ANALYZE partitioned.f,partitioned.l,partitioned.s;

--
-- The test.
--

SET enable_partitionwise_join = 'off';
\timing on
SELECT count(*) FROM partitioned.f AS f, partitioned.l AS l
WHERE f.a=l.a;
\timing off

SET enable_partitionwise_join = 'on';
\timing on
SELECT count(*) FROM partitioned.f AS f, partitioned.l AS l
WHERE f.a=l.a;
\timing off
