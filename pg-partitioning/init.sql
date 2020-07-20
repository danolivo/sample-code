DROP TABLE IF EXISTS d CASCADE;

-- Basic schema
CREATE TABLE d (
	id INT CHECK (id >= 0 AND id <= 10000), -- range 0 - 10000
	time TIMESTAMP,
	pld TEXT,
	PRIMARY KEY (id, time)
) PARTITION BY RANGE (id);
CREATE TABLE d_1 PARTITION OF d (id) FOR VALUES FROM (0) TO (2500)
	PARTITION BY RANGE (time);
CREATE TABLE d_2 PARTITION OF d (id) FOR VALUES FROM (2500) TO (5000)
	PARTITION BY RANGE (time);
CREATE TABLE d_3 PARTITION OF d (id) FOR VALUES FROM (5000) TO (7500)
	PARTITION BY RANGE (time);
CREATE TABLE d_4 PARTITION OF d (id) FOR VALUES FROM (7500) TO (10001)
	PARTITION BY RANGE (time);

-- Initial data
CREATE TABLE d_1_0 PARTITION OF d_1 (time) FOR VALUES FROM ('2020-01-01 00:00:00') TO ('2020-01-31 23:59:59');
CREATE TABLE d_2_0 PARTITION OF d_2 (time) FOR VALUES FROM ('2020-01-01 00:00:00') TO ('2020-01-31 23:59:59');
CREATE TABLE d_3_0 PARTITION OF d_3 (time) FOR VALUES FROM ('2020-01-01 00:00:00') TO ('2020-01-31 23:59:59');
CREATE TABLE d_4_0 PARTITION OF d_4 (time) FOR VALUES FROM ('2020-01-01 00:00:00') TO ('2020-01-31 23:59:59');

-- Each device triggered an event this month
INSERT INTO d (id, time, pld) SELECT gs.* , timestamp '2020-01-01 00:00:00' +
	random() * (timestamp '2020-01-31 23:59:59' - timestamp '2020-01-01 00:00:00'), 'abc' FROM generate_series(0,10000) AS gs;

CREATE INDEX ON d USING brin (id, time);
