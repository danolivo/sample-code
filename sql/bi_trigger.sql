DROP TRIGGER IF EXISTS increase_by_one_trigger ON pgbench_accounts CASCADE;

CREATE OR REPLACE FUNCTION increase_by_one() 
   RETURNS trigger AS
$BODY$
BEGIN
	NEW.abalance := NEW.abalance + 1;
	RETURN NEW;
END;
$BODY$
LANGUAGE PLPGSQL;

CREATE TRIGGER increase_by_one_trigger
BEFORE INSERT
   ON pgbench_accounts
   FOR EACH ROW
       EXECUTE PROCEDURE increase_by_one();
