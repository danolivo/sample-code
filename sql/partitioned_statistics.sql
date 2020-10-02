DROP TABLE IF EXISTS test1 CASCADE;
 
CREATE TABLE test1 (
    id integer
) PARTITION BY hash (id);
 
CREATE TABLE test1_0 PARTITION OF test1 FOR VALUES WITH (modulus 3, remainder 0);
CREATE TABLE test1_1 PARTITION OF test1 FOR VALUES WITH (modulus 3, remainder 1);
CREATE TABLE test1_2 PARTITION OF test1 FOR VALUES WITH (modulus 3, remainder 2);
 
INSERT INTO test1 (SELECT * FROM generate_series(1,100) AS q);
SELECT tablename, attname, inherited, avg_width, n_distinct, histogram_bounds FROM pg_stats WHERE tablename ~ 'test1';
SELECT oid, relname, reltuples, relpages FROM pg_class WHERE relname ~ 'test1';
VACUUM ANALYZE;
SELECT tablename, attname, inherited, avg_width, n_distinct, histogram_bounds FROM pg_stats WHERE tablename ~ 'test1';
SELECT oid, relname, reltuples, relpages FROM pg_class WHERE relname ~ 'test1';
VACUUM ANALYZE test1;
SELECT tablename, attname, inherited, avg_width, n_distinct FROM pg_stats WHERE tablename ~ 'test1';
SELECT oid, relname, reltuples, relpages FROM pg_class WHERE relname ~ 'test1';
EXPLAIN ANALYZE SELECT * FROM test1 WHERE id > 10 AND id < 30;
 
-- Influence of parent table statistics
DELETE FROM pg_statistic WHERE starelid IN (SELECT oid FROM pg_class WHERE relname = 'test1');
SELECT tablename, attname, inherited, avg_width, n_distinct FROM pg_stats WHERE tablename = 'test1';
EXPLAIN ANALYZE SELECT * FROM test1 WHERE id > 10 AND id < 30;

INSERT INTO test1 (SELECT * FROM generate_series(101,200) AS q);
VACUUM ANALYZE;
select * from pg_stats where tablename ~ 'test1';
EXPLAIN ANALYZE SELECT * FROM test1 WHERE id > 100 AND id < 150;
