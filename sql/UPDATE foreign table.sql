DROP EXTENSION IF EXISTS postgres_fdw CASCADE;
DROP TABLE IF EXISTS b1 CASCADE;

CREATE EXTENSION postgres_fdw;

CREATE SERVER lb FOREIGN DATA WRAPPER postgres_fdw;
CREATE USER MAPPING FOR CURRENT_USER SERVER lb;

CREATE TABLE b1 (a int, b int);
CREATE FOREIGN TABLE r1 (a int, b int) SERVER lb OPTIONS (table_name 'b1');
INSERT INTO b1 SELECT generate_series(1,100), -generate_series(1,100);
ANALYZE;
ANALYZE r1;

--SET enable_hashjoin = 'off';
--SET enable_mergejoin = 'off';

explain verbose
UPDATE r1 d
	SET a = CASE WHEN random() >= 0 THEN 5 ELSE 6 END
FROM (SELECT ROW(q2,-q2) FROM generate_series(1,10) AS q2) AS q1 (a) WHERE q1 = ROW(d);

UPDATE r1 d
	SET a = CASE WHEN random() >= 0 THEN 5 ELSE 6 END
FROM (SELECT ROW(q2,-q2) FROM generate_series(1,10) AS q2) AS q1 (a) WHERE q1 = ROW(d);


UPDATE b1 d
	SET a = CASE WHEN random() >= 0 THEN 5 ELSE 6 END
FROM (SELECT ROW(q2,-q2) FROM generate_series(1,10) AS q2) AS q1 (a) WHERE q1 = ROW(d);