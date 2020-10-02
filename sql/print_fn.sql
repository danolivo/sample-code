CREATE OR REPLACE FUNCTION print(txt text) RETURNS text AS $$
BEGIN
	RETURN txt;
END;
$$  LANGUAGE plpgsql;

SELECT print('a');
SELECT oid FROM pg_class WHERE relname = 'pg_class'; \gset
SELECT print(:oid::text);

