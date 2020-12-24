DROP EXTENSION aqo CASCADE;
CREATE EXTENSION aqo;
DROP EXTENSION IF EXISTS postgres_fdw CASCADE;
DROP TABLE IF EXISTS l,f,sf,sl1,sl2 CASCADE;

CREATE EXTENSION postgres_fdw;
CREATE SERVER loopback FOREIGN DATA WRAPPER postgres_fdw OPTIONS (fdw_startup_cost '1000', fdw_tuple_cost '10');
CREATE USER MAPPING FOR PUBLIC SERVER loopback;

CREATE TABLE l(a int, b int) PARTITION BY HASH (a);
--CREATE TABLE l1(a int);
--CREATE TABLE l2(a int);

CREATE TABLE l1 PARTITION OF l FOR VALUES WITH (modulus 2, remainder 0);
CREATE TABLE l2 PARTITION OF l FOR VALUES WITH (modulus 2, remainder 1);

INSERT INTO l (SELECT gs.*, -gs.*+1 FROM generate_series(1,1E4) AS gs);
CREATE TABLE f(a int, b int) PARTITION BY HASH (a);
CREATE FOREIGN TABLE f1 PARTITION OF f FOR VALUES WITH (modulus 2, remainder 0) SERVER loopback OPTIONS (table_name 'l1');
CREATE FOREIGN TABLE f2 PARTITION OF f FOR VALUES WITH (modulus 2, remainder 1) SERVER loopback OPTIONS (table_name 'l2');


CREATE TABLE sf(a int, b int) PARTITION BY HASH (a);
CREATE TABLE sl1(a int, b int);
CREATE TABLE sl2(a int, b int);
CREATE FOREIGN TABLE sf1 PARTITION OF sf FOR VALUES WITH (modulus 2, remainder 0) SERVER loopback OPTIONS (table_name 'sl1');
CREATE FOREIGN TABLE sf2 PARTITION OF sf FOR VALUES WITH (modulus 2, remainder 1) SERVER loopback OPTIONS (table_name 'sl2');
INSERT INTO sf (a,b) (SELECT 1, 0 FROM generate_series(1,100) as gs);
INSERT INTO sf (a,b) (SELECT 2, 0 FROM generate_series(1,100) as gs);

--CREATE FOREIGN TABLE f(a int) SERVER loopback OPTIONS (table_name 'l');
SET enable_partitionwise_join = 'on';
--explain analyze verbose SELECT * FROM f f1 JOIN sf f2 ON f1.a = f2.a WHERE f1.a < 10 AND f2.a > -5;
--explain analyze verbose SELECT * FROM f INNER JOIN (SELECT f1.a FROM f f1 JOIN sf f2 ON f1.a = f2.a WHERE f1.a < 10 AND f2.a > -5) as a1 ON f.a = a1.a;
select count(*) from sf;
