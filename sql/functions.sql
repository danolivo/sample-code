DROP FUNCTION IF EXISTS f1;
CREATE FUNCTION f1(relid regclass) returns text as $$
DECLARE
  result text;
BEGIN
  raise notice 'Value: %', relid;
  -- Check that table is global already.
  SELECT oid FROM pg_class t WHERE t.oid = relid INTO result;
  RETURN result;
END $$ language plpgsql;

SELECT * FROM f1('pg_class');
--SELECT * FROM f1(1259);
