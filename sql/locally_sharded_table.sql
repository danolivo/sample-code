DROP EXTENSION IF EXISTS postgres_fdw CASCADE;
DROP TABLE IF EXISTS l, l_1, l_2, l_3, l_4 CASCADE;

CREATE EXTENSION postgres_fdw;
CREATE SERVER loopback FOREIGN DATA WRAPPER postgres_fdw;
CREATE USER MAPPING FOR PUBLIC SERVER loopback;

CREATE TABLE l(a int) PARTITION BY HASH (a);
CREATE TABLE l_1 (a int);
CREATE TABLE l_2 (a int);
CREATE TABLE l_3 (a int);
CREATE TABLE l_4 (a int);
CREATE TABLE l_0 PARTITION OF l FOR VALUES WITH (modulus 5, remainder 0);
CREATE FOREIGN TABLE f_1 PARTITION OF l FOR VALUES WITH (modulus 5, remainder 1) SERVER loopback OPTIONS (table_name 'f_1');
CREATE FOREIGN TABLE f_2 PARTITION OF l FOR VALUES WITH (modulus 5, remainder 2) SERVER loopback OPTIONS (table_name 'f_2');
CREATE FOREIGN TABLE f_3 PARTITION OF l FOR VALUES WITH (modulus 5, remainder 3) SERVER loopback OPTIONS (table_name 'f_3');
CREATE FOREIGN TABLE f_4 PARTITION OF l FOR VALUES WITH (modulus 5, remainder 4) SERVER loopback OPTIONS (table_name 'f_4');

CREATE FOREIGN TABLE frgn (a int) SERVER loopback OPTIONS (table_name 'local');

INSERT INTO l (a) SELECT * FROM generate_series(1,1000);
INSERT INTO frgn (a) SELECT * FROM generate_series(1,10);
VACUUM ANALYZE;

SET enable_hashjoin = 'off';
SET enable_mergejoin = 'off';
explain analyze SELECT * FROM frgn,l WHERE frgn.a < 10 AND frgn.a = l.a;
