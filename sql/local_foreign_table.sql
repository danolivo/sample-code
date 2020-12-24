DROP EXTENSION IF EXISTS postgres_fdw CASCADE;
DROP TABLE IF EXISTS l CASCADE;

CREATE EXTENSION postgres_fdw;
CREATE SERVER loopback FOREIGN DATA WRAPPER postgres_fdw;
CREATE USER MAPPING FOR PUBLIC SERVER loopback;

CREATE TABLE l(a int);
CREATE FOREIGN TABLE f(a int) SERVER loopback OPTIONS (table_name 'l');

--COPY (SELECT * FROM generate_series(1,100) as gs) TO '/home/andrey/1.txt';
--COPY f FROM '/home/andrey/1.txt';
