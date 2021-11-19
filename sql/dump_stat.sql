CREATE OR REPLACE FUNCTION stat_to_json(relname name)
RETURNS SETOF JSON AS '
SELECT row_to_json(p.*) FROM (
	WITH stareloid(rn) AS (
		SELECT oid FROM pg_class c WHERE c.relname=$1
	)
	SELECT
		starelid::regclass AS starelname,
		a.attname AS staattname,
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
	FROM pg_statistic s, pg_attribute a, stareloid
	WHERE
		starelid = stareloid.rn
		AND s.starelid = a.attrelid
		AND s.staattnum = a.attnum
		AND s.staattnum = 1
) AS p;
' LANGUAGE SQL;

DROP TABLE IF EXISTS b,b_copy CASCADE;
CREATE TABLE b AS SELECT a, ('abc' || a)::text AS payload FROM generate_series(1,342) AS a;
ANALYZE b;


CREATE TABLE b_copy AS SELECT * FROM b;

WITH js1 AS (
	SELECT js FROM stat_to_json('b') AS js
)
SELECT json_to_record(js1.js) AS t(a text) FROM js1;

