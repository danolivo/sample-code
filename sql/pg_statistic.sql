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

-- Ищем проблемы в staop
DROP SCHEMA IF EXISTS a CASCADE;
CREATE SCHEMA a;
ALTER TYPE integer SET SCHEMA a;
--CREATE TYPE a.t1 AS (f1 int);
--ALTER TABLE :namespace.:tblname ADD COLUMN b a.t1 DEFAULT (NULL);
ANALYZE :namespace.:tblname;

-- Получить имена и типы атрибутов, которые попадают в статистику
SELECT row_to_json(q::record) FROM
(SELECT	attname,
		atttypid::regtype AS atttypname,
		(SELECT typnamespace::regnamespace FROM pg_type WHERE oid = atttypid) AS atttypnspname
FROM pg_attribute
	WHERE attrelid = :reloid AND attnum IN
		-- Получить список атрибутов для сериализации
		(SELECT staattnum FROM pg_statistic WHERE starelid = :reloid)
) AS q;

--SELECT attname FROM pg_stats WHERE schemaname = 'public' AND tablename = 't';
SELECT row_to_json(q::record) FROM (SELECT
		starelid::regclass,
		staattnum,
		stainherit,
		stanullfrac,
		stawidth,
		stadistinct,
		stakind1,
		stakind2,
		stakind3,
		stakind4,
		stakind5,
		staop1::regoperator,
		staop2::regoperator,
		staop3::regoperator,
		staop4::regoperator,
		staop5::regoperator,
		stacoll1::regcollation,
		stacoll2::regcollation,
		stacoll3::regcollation,
		stacoll4::regcollation,
		stacoll5::regcollation,
		stanumbers1,
		stanumbers2,
		stanumbers3,
		stanumbers4,
		stanumbers5,
		stavalues1,
		stavalues2,
		stavalues3,
		stavalues4,
		stavalues5
	FROM
		pg_statistic
	WHERE
		starelid = :reloid) as q;
