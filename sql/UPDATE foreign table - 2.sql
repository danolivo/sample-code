
DROP EXTENSION IF EXISTS postgres_fdw CASCADE;
DROP TABLE IF EXISTS b1,b2,fpt CASCADE;

create extension postgres_fdw;

DO $d$
    BEGIN
        EXECUTE $$CREATE SERVER lb1 FOREIGN DATA WRAPPER postgres_fdw
            OPTIONS (dbname '$$||current_database()||$$',
                     port '$$||current_setting('port')||$$')$$;
   END;
$d$;

CREATE USER MAPPING FOR CURRENT_USER SERVER lb1;

CREATE TABLE b1 (a int, b int, c int);
CREATE TABLE b2 (a int, b int, c text);

CREATE TABLE fpt(a int, b int) PARTITION BY HASH (a);
CREATE FOREIGN TABLE r1 PARTITION OF fpt FOR VALUES WITH (modulus 2, remainder 0) SERVER lb1 OPTIONS (table_name 'b1');
CREATE FOREIGN TABLE r2 PARTITION OF fpt FOR VALUES WITH (modulus 2, remainder 1) SERVER lb1 OPTIONS (table_name 'b2');

INSERT INTO b1 SELECT generate_series(1,100), generate_series(1,100), 1;
INSERT INTO b2 SELECT generate_series(1,100), generate_series(1,100), 'abc';

SET enable_partitionwise_join = 'on';
explain verbose UPDATE fpt d
	SET a = CASE WHEN (current_timestamp > '2012-02-02'::timestamp)
				THEN 5
				ELSE 6
			END
FROM fpt AS t(a, b) WHERE d.a = (t.a);
