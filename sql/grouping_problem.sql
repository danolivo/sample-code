DROP TABLE IF EXISTS a;

CREATE TABLE a (x int);
explain analyze verbose SELECT * FROM a; -- OK
explain analyze verbose SELECT count(*) FROM a; -- OK. Planner calculates cardinality without AQO here.
INSERT INTO a (SELECT gs.* FROM generate_series(1,1000) AS gs);
ANALYZE a;
explain analyze verbose SELECT count(x) FROM a GROUP BY(x) HAVING (count(x) > 1); -- NOT OK.
explain analyze verbose SELECT count(x) FROM a GROUP BY(x) HAVING (count(x) > 1);

