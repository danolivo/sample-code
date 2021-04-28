DROP TABLE IF EXISTS t CASCADE;

CREATE TABLE t AS (
	SELECT CASE WHEN (random()<0.5) THEN true ELSE false END AS active
	FROM generate_series(1,100)
);

CREATE INDEX t_active_idx ON t (active) WHERE active;
CREATE INDEX t_idx1 ON t (active);

-- UPDATE pg_class SET reltuples=0 WHERE relname='t_active_idx' OR relname='t_idx1';
-- SELECT oid,relname,reltuples FROM pg_class WHERE relname='t_active_idx' OR relname='t_idx1';
VACUUM ANALYZE t;
SELECT oid,relname,reltuples FROM pg_class WHERE relname='t_active_idx' OR relname='t_idx1';
UPDATE pg_class SET reltuples=0 WHERE relname='t_active_idx' OR relname='t_idx1';
ANALYZE t;
SELECT oid,relname,reltuples FROM pg_class WHERE relname='t_active_idx' OR relname='t_idx1';
EXPLAIN SELECT * FROM t WHERE active=true;