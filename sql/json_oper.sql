-- На входе название таблицы и её namespace.
\set namespace public
\set tblname 't'

-- Initial operations
DROP TABLE IF EXISTS :namespace.:tblname;
CREATE TABLE :namespace.:tblname(id int, a text);
INSERT INTO :namespace.:tblname (SELECT gs.*, 'abc' || gs.* FROM generate_series(1,200,3) AS gs	);
ANALYZE :namespace.:tblname;

SELECT json_build_object('relation', json_build_object('namespace', :'namespace', 'tblname', :'tblname'));

-- Получить OID namespace и таблицы
SELECT oid AS nspoid FROM pg_namespace WHERE nspname = :'namespace'; \gset
SELECT oid AS reloid FROM pg_class where relname = :'tblname' AND relnamespace = :nspoid; \gset

-- Получаем OID оператора
--SELECT staop1 AS opoid FROM pg_statistic WHERE starelid = :reloid AND staattnum = 1; \gset

--SELECT oprnamespace::regnamespace, oprname,  FROM pg_operator WHERE oid = :opoid;
DROP SCHEMA IF EXISTS a CASCADE;
CREATE SCHEMA a;
CREATE TYPE a.t1 AS (f1 int);
CREATE TABLE a.t();
SELECT oid AS nspoid1 FROM pg_namespace WHERE nspname = 'a'; \gset
SELECT oid::regclass FROM pg_class where relname = 't' AND relnamespace = :nspoid1;
--ALTER TABLE :namespace.:tblname ADD COLUMN b a.t1 DEFAULT (NULL);
--ALTER TYPE int4 SET SCHEMA a;
--SELECT oid, oid::regtype FROM pg_type WHERE typname = 't1' OR typname = 'int2' or typname = 'int4';
