DROP TABLE IF EXISTS test CASCADE;

CREATE TABLE test (
	schema_rev smallint DEFAULT 0, -- Maybe here we can use CHAR, 1-byte type for reduce the size of relation?
	user_id int,
	payload TEXT
) PARTITION BY LIST(schema_rev);

CREATE TABLE test_0 PARTITION OF test (schema_rev) FOR VALUES IN (0) PARTITION BY HASH (user_id);
CREATE TABLE test_0_0 PARTITION OF test_0 (user_id) FOR VALUES WITH (modulus 2, remainder 0);
CREATE TABLE test_0_1 PARTITION OF test_0 (user_id) FOR VALUES WITH (modulus 2, remainder 1);

-- Fill partitioned table
INSERT INTO test (user_id, payload) SELECT gs.* , 'data' || gs.* FROM generate_series(1,100) AS gs;

-- Check data
SELECT * FROM
	(SELECT count(*) AS overall FROM test) AS a,
	(SELECT count(*) AS t0_0 FROM test_0_0) AS b,
	(SELECT count(*) AS t0_1 FROM test_0_1) AS c;

-- Add new server, new partition schema:
CREATE TABLE test_1 PARTITION OF test (schema_rev) FOR VALUES IN (1) PARTITION BY HASH (user_id);
CREATE TABLE test_1_0 PARTITION OF test_1 (user_id) FOR VALUES WITH (modulus 3, remainder 0);
CREATE TABLE test_1_1 PARTITION OF test_1 (user_id) FOR VALUES WITH (modulus 3, remainder 1);
CREATE TABLE test_1_2 PARTITION OF test_1 (user_id) FOR VALUES WITH (modulus 3, remainder 2);

-- Set new DEFAULT revision
ALTER TABLE test ALTER COLUMN schema_rev SET DEFAULT 1; 

-- Add to partitioned table
INSERT INTO test (user_id, payload) SELECT gs.* , 'data' || gs.* FROM generate_series(1,100) AS gs;

-- Check that additions routed into new schema
SELECT * FROM
	(SELECT count(*) AS overall FROM test) AS a,
	(SELECT count(*) AS t0 FROM test_0) AS b,
	(SELECT count(*) AS t1 FROM test_1) AS c,
	(SELECT count(*) AS t1_0 FROM test_1_0) AS d,
	(SELECT count(*) AS t1_1 FROM test_1_1) AS e,
	(SELECT count(*) AS t1_2 FROM test_1_2) AS f;

