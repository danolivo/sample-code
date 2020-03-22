#!/usr/bin/env python

"""
    Adaptive Query Optimizer (AQO) test script. Uses the JOB test queries and
    already preconfigured & launched imdb database.
"""
import json
import os
import psycopg2
import subprocess
import sys

sqlpath = "/home/andrey/PostgresPro/JOB/JOB_Queries/"

# Convergence issues
TestsMaxNum = 100
TestMinExecutions = 3 # Minimum learning iterations
ConvergenceError = 0.1
WarmingNoAQOIters = 4

# Set environment variables
PWD = os.environ["PWD"]
os.environ["PATH"] = os.environ["PATH"] + ":" + PWD + "/tmp_install/bin/"
os.environ["LD_LIBRARY_PATH"] = os.environ["LD_LIBRARY_PATH"] + ":" + PWD + "/tmp_install/lib"
PGDATA = os.environ["PGDATA"] = "pgdata_imdb"
lines = (subprocess.run(args = [ 'whoami' ], universal_newlines = True, stdout = subprocess.PIPE)).stdout.splitlines()
PGDATABASE = os.environ["PGDATABASE"] = lines[0]
PGHOST = os.environ["PGHOST"] = "localhost"
PGPORT = os.environ["PGPORT"] = "5432"

# Clean previous data & processes
subprocess.call("pg_ctl stop", shell=True)
subprocess.call("pkill -9 -U `whoami` -e postgres", shell=True)
subprocess.call("make > /dev/null && make -C contrib > /dev/null && \
    make install > /dev/null && make -C contrib install > /dev/null", shell=True)
subprocess.call("rm logfile.log", shell=True)

subprocess.call("pg_ctl -l logfile.log start", shell=True)

# Set up preferences
con = psycopg2.connect("")
con.autocommit = True
cur = con.cursor()
cur.execute("DROP EXTENSION IF EXISTS AQO;")
cur.execute("CREATE EXTENSION IF NOT EXISTS AQO;")

old_isolation_level = con.isolation_level
con.set_isolation_level(0)
cur.execute("ALTER SYSTEM SET aqo.mode = 'learn';")
cur.execute("ALTER SYSTEM SET aqo.use_common_space = 'false';")
cur.execute("ALTER SYSTEM SET aqo.use_assumptions = 'true';")
cur.execute("ALTER SYSTEM SET aqo.sel_trust_factor = 0.0001;")
cur.execute("ALTER SYSTEM SET aqo.force_collect_stat = 'false';")
con.set_isolation_level(old_isolation_level)
con.commit()
cur.execute("SELECT pg_reload_conf();")
cur.close()

# Execute test

print("Hello!")
onlyfiles = [f for f in os.listdir(sqlpath) if os.path.isfile(os.path.join(sqlpath, f))]
onlyfiles.sort()

if len(sys.argv) > 1:
    onlyfiles = sys.argv[1:]

for filename in onlyfiles:

    f = open(sqlpath + filename, "r")
    print("Use file", sqlpath + filename)
    query = f.read()
    query = "EXPLAIN (ANALYZE ON, VERBOSE ON, FORMAT JSON) " + query
    f.close()

    # Do warm shots in disabled mode
    cur = con.cursor()
    cur.execute("SET aqo.mode = 'disabled';")
    cur.execute("SET aqo.force_collect_stat = 'true';")
    cur.execute("SET aqo.sel_trust_factor = 1;")

    times = [] # Execution time list without aqo
    for i in range(WarmingNoAQOIters):
        cur.execute(query)

        result = cur.fetchone()[0][0]
        times.append(float(result["Execution Time"]))

    print("Base (AQO disabled) execution times:", times)
    cur.execute(query)
    result = cur.fetchone()[0][0]
    qhash = int(result["Query hash"])
    njoins = int(result["JOINS"])
    aqo_mode = result["AQO mode"]
    assert aqo_mode == "DISABLED"
    use_aqo = bool(result["Using aqo"])
    assert use_aqo == False
    etimeNoAQO = float(result["Execution Time"])
    ptimeNoAQO = float(result["Planning Time"])

    cur.execute("SELECT public.aqo_enable_query(" + str(qhash) + ");")
    cur.close()
    con.close() # To clean GUC's
    print("Test case:", filename, ", NJ: ", njoins, ", Hash: ", qhash, "Base time: ", etimeNoAQO, "Planning time:", ptimeNoAQO)
    print("{0:3s}\t{1:7.7s}\t{2:7s}\t{3:3s}\t{4:3s}\t{5:7.7s}".format("No.", "Time", "Err", "AQO", "Na", "PTime"))

    # --------------------------------------------------------------------------
    # Do the test
    
    con = psycopg2.connect("")
    con.autocommit = True
    counter = 0
    errors = []
    MinExecTime = -1.
    etime = -1.
    ptime = -1.
    LastError = -1.
    for i in range(TestsMaxNum):
        cur = con.cursor()
        try:
            cur.execute(query)
        except psycopg2.errors.DiskFull as err:
            print("Disk full: {0}".format(err))
            continue;
        except:
            print("Unexpected error:", sys.exc_info()[0])

        result = cur.fetchone()[0][0]
        aqo_mode = result["AQO mode"]
        assert aqo_mode == "LEARN"
        use_aqo = bool(result["Using aqo"])
        etime = float(result["Execution Time"])
        ptime = float(result["Planning Time"])
        na = int(result["Assumptions used"])

        if MinExecTime < 0 or MinExecTime > etime:
            MinExecTime = etime

        cur.execute("SELECT err_aqo FROM aqo_status(" + str(qhash) + ");")
        err = float(cur.fetchone()[0])
        cur.close()
        counter += 1
        print("{0:3d}\t{1:7.0f}\t{2:7.1E}\t{3:3d}\t{4:3d}\t{5:7.0f}".format(counter, etime, err, use_aqo, na, ptime))
        sys.stdout.flush()

        if err < 0.:
            print("SKIP the query because of not executed nodes exists")
            break

        errors.append(err)
        # Hard condition for the going to next iteration
        if i < TestMinExecutions or na > 0:
            continue

        ConvergenceAchieved = True
        for err in errors[-TestMinExecutions:]:
            if err > ConvergenceError:
                ConvergenceAchieved = False
                break

        if ConvergenceAchieved:
            break

    if len(errors) > 0:
        LastError = errors[-1]

    # Do last shot with AQO in frozen mode.
    cur = con.cursor()
    cur.execute("SET aqo.mode = 'frozen';")
    cur.execute("SET aqo.sel_trust_factor = 1;")
    cur.execute(query)

    result = cur.fetchone()[0][0]
    aqo_mode = str(result["AQO mode"])
    FrozenTime = float(result["Execution Time"])
    cur.close()
    print("Test {0} finished. Last error: {1:7.1E}, Last time: {2} \
        MinTime: {3} Base time: {4}. In {5} mode time is {6}"
        .format(counter, LastError, etime, MinExecTime, etimeNoAQO, aqo_mode,
            FrozenTime))

con.close()

print("That's all")
