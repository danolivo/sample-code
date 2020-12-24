DROP EXTENSION IF EXISTS postgres_fdw CASCADE;
DROP TABLE IF EXISTS l, l1,l2,l3 CASCADE;

CREATE EXTENSION postgres_fdw;
CREATE SERVER loopback FOREIGN DATA WRAPPER postgres_fdw OPTIONS (use_remote_estimate 'on');
CREATE USER MAPPING FOR PUBLIC SERVER loopback;

CREATE TABLE l(a int, b int) PARTITION BY HASH (a);
CREATE TABLE l1(a int, b int);
CREATE TABLE l2(a int, b int);
CREATE TABLE l3(a int, b int);
CREATE FOREIGN TABLE fl1 PARTITION OF l FOR VALUES WITH (modulus 3, remainder 0) SERVER loopback OPTIONS (table_name 'l1');
CREATE FOREIGN TABLE fl2 PARTITION OF l FOR VALUES WITH (modulus 3, remainder 1) SERVER loopback OPTIONS (table_name 'l2');
CREATE FOREIGN TABLE fl3 PARTITION OF l FOR VALUES WITH (modulus 3, remainder 2) SERVER loopback OPTIONS (table_name 'l3');

INSERT INTO l (SELECT gs.* % 100, 1 FROM generate_series(1,1000) AS gs);
ANALYZE; -- Stabilize test results.

-- Force planner to use parallel plan.
SET parallel_setup_cost = 0.01;
SET cpu_tuple_cost = 10;

-- Show explain without parallel-safe foreign scan.
explain (COSTS OFF, SUMMARY OFF, TIMING OFF)
	SELECT count(*) FROM l x WHERE x.a < 1000 GROUP BY x.a;

SET postgres_fdw.parallel_safe = 'true';

-- Show explain with parallel-safe foreign scan.
explain (COSTS OFF, SUMMARY OFF, TIMING OFF)
	SELECT count(*) FROM l x WHERE x.a < 1000 GROUP BY x.a;

RESET postgres_fdw.parallel_safe;
RESET parallel_setup_cost;
RESET cpu_tuple_cost;

