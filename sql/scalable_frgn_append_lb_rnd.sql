DROP EXTENSION IF EXISTS postgres_fdw CASCADE;

CREATE EXTENSION postgres_fdw;

DO $$
DECLARE
parts integer := 32;
i integer;
sql text;
BEGIN
	FOR i IN 1..parts
    LOOP
    	sql = format('DROP TABLE IF EXISTS l%s', i);
    	execute sql;
    END LOOP;
    
    FOR i IN 1..parts
    LOOP
		sql = format('CREATE SERVER loopback%s FOREIGN DATA WRAPPER postgres_fdw OPTIONS (async_capable %L)', i, 'true');
        execute sql;
        sql = format('CREATE USER MAPPING FOR PUBLIC SERVER loopback%s', i);
        execute sql;
        sql = format('CREATE TABLE l%s(a int)', i);
        execute sql;
		sql = format('CREATE FOREIGN TABLE f%s(a int) SERVER loopback%s OPTIONS (table_name %L)', i, i, 'l'||i);
		execute sql;
		sql = format('INSERT INTO l%s SELECT * FROM generate_series(1,%s)', i, floor(random()*100000));
		execute sql;
    END LOOP;
END$$;

ANALYZE;

-- Test
DROP FUNCTION IF EXISTS union_all;
CREATE OR REPLACE FUNCTION union_all(parts integer) RETURNS text AS
$$
DECLARE
	i integer;
	sql text;
BEGIN
	sql = 'EXPLAIN (ANALYZE, TIMING OFF, COSTS OFF) (SELECT * FROM f1)';
	
	FOR i IN 2..parts
	LOOP
		sql = format('%s UNION ALL (SELECT * FROM f%s)', sql, i);
	END LOOP;
    sql = format('%s;', sql);
	RETURN sql;
END$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS rnd_union_all_limit;
CREATE OR REPLACE FUNCTION rnd_union_all_limit(parts integer) RETURNS text AS
$$
DECLARE
	i integer;
	sql text;
	rnd real;
	rnd1 real;
BEGIN
	sql = 'EXPLAIN (ANALYZE, TIMING OFF, COSTS OFF) (SELECT * FROM f1)';
	
	FOR i IN 2..parts
	LOOP
		SELECT random() INTO rnd;
		
		IF (rnd > 0.5) THEN
			SELECT floor(random()*1000)+1 INTO rnd1;
			sql = format('%s UNION ALL (SELECT * FROM f%s LIMIT %s)', sql, i, rnd1);
		END IF;
		
		sql = format('%s UNION ALL (SELECT * FROM f%s)', sql, i);
	END LOOP;
    sql = format('%s;', sql);
	RETURN sql;
END$$ LANGUAGE plpgsql;

SELECT union_all(32) AS tmp; \gset
:tmp
SELECT union_all(32) AS tmp; \gset
:tmp

