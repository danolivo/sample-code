DROP EXTENSION IF EXISTS postgres_fdw CASCADE;
DROP TABLE IF EXISTS b1 CASCADE;

CREATE EXTENSION postgres_fdw;

CREATE SERVER lb FOREIGN DATA WRAPPER postgres_fdw;
CREATE USER MAPPING FOR CURRENT_USER SERVER lb;

CREATE USER MAPPING FOR CURRENT_USER SERVER loopback;

CREATE TABLE b1 (a int, b int, c text);
CREATE FOREIGN TABLE r1 (a int, b int) SERVER lb OPTIONS (table_name 'b1');

INSERT INTO b1 SELECT generate_series(1,100), -generate_series(1,100), 'abc';

ANALYZE;
ANALYZE r1;

explain verbose update r1 d
	SET a = CASE WHEN random() >= 0 THEN 5 ELSE 6 END
FROM r1 AS t (a, b) WHERE d.a = (t.a);
update r1 d
	SET a = CASE WHEN random() >= 0 THEN 5 ELSE 6 END
FROM r1 AS t (a, b) WHERE d.a = (t.a);

explain verbose
UPDATE r1 d
	SET a = CASE WHEN random() >= 0 THEN 5 ELSE 6 END
FROM b1 AS t (a, b) WHERE d.a = (t.a);

SET enable_hashjoin = 'off';
SET enable_mergejoin = 'off';

explain verbose
UPDATE r1 d
	SET a = CASE WHEN random() >= 0 THEN 5 ELSE 6 END
FROM (SELECT ROW(q2,-q2,'avc') FROM generate_series(1,10) AS q2) AS q1 (a) WHERE q1 = ROW(d);

UPDATE r1 d
	SET a = CASE WHEN random() >= 0 THEN 5 ELSE 6 END
FROM (SELECT ROW(q2,-q2,'avc') FROM generate_series(1,10) AS q2) AS q1 (a) WHERE q1 = ROW(d);

-- ERROR:  attribute 2 of type record has wrong type
-- DETAIL:  Table has type record, but query expects r1.

UPDATE b1 d
	SET a = CASE WHEN random() >= 0 THEN 5 ELSE 6 END
FROM (SELECT ROW(q2,-q2,'avc') FROM generate_series(1,10) AS q2) AS q1 (a) WHERE q1 = ROW(d);

explain verbose
UPDATE r1 d
	SET a= case when (current_timestamp>'2012-02-02'::timestamp) then 5 else 6 end
FROM r1 AS t (a, b) WHERE d.a = (t.a);

EXPLAIN (VERBOSE)
SELECT * FROM r1 f1, (SELECT ROW(f2.*) FROM r1 f2) AS q1;

EXPLAIN (VERBOSE)
SELECT * FROM (SELECT ROW(f1.*) AS rw1 FROM r1 f1) AS q1, (SELECT ROW(f2.*) AS rw2 FROM r1 f2) AS q2;

EXPLAIN (VERBOSE)
SELECT * FROM (SELECT ROW(-f1.a, -f1.b) AS rw1 FROM r1 f1) AS q1, (SELECT ROW(f2.*) AS rw2 FROM r1 f2) AS q2
WHERE rw1 = rw2;