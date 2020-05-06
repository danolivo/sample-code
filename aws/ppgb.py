#!/usr/bin/env python

"""
	AWS. Execute the test
"""

import json
import os
import subprocess # execute shell scripts
import sys
import psycopg2

clients = 100

# Set environment
os.environ["PGDATABASE"] = "ubuntu"
os.environ["PGPORT"] = "5432"
os.environ["PGUSER"] = "shardman"
os.environ["PGPASSWORD"] = "shard12345"

NodesNum = 0
publicIpAddress = []
privateAddress = []

# ##############################################################################
#
# Load list of the shardman nodes
#
# ##############################################################################
os.system("aws ec2 describe-instances --filters 'Name=tag:group,Values=shardman' > nodelist.txt")

with open('nodelist.txt') as json_file:
    k = json.load(json_file)
    for c in k["Reservations"]:

        if (c["Instances"][0]["State"]["Name"] != "running"):
            continue

        publicIpAddress.append(c["Instances"][0]["PublicIpAddress"])
        privateAddress.append(c["Instances"][0]["PrivateIpAddress"])
        NodesNum += 1

if (NodesNum == 0):
    print("No one node found")
    sys.exit(1)

print("Total nodes in shardman: ", NodesNum)
for i in range(NodesNum):
    print(i, " ",  publicIpAddress[i], " ", privateAddress[i])

# ##############################################################################
#
# Execute test
#
# ##############################################################################

pids = []
for addr in privateAddress:
    pid = os.fork()

    if (pid == 0):
        os.system("pgbench -n -P 5 -c "+str(clients/3)+" -j "+str(clients/3)+" --max-tries 1000 -f test.pgb -T 60 -h " + addr)
        sys.exit(0)

    print "pid: ", pid, ", addr: ", addr
    pids.append(pid)

for pid in pids:
    os.waitpid(pid, 0)

# ##############################################################################
#
# Show data and test consistency markers
#
# ##############################################################################

con = psycopg2.connect(host=privateAddress[1])
cur = con.cursor()
cur.execute("SELECT (itp > 4 AND itp < 6) AS int_transfer_percentage \
	FROM (SELECT 100*sum(nit)/sum(net) AS itp FROM accounts) AS pr;")
res = cur.fetchall()[0]
print res
# Sum of total current value and external transfers must be equal to <accounts number> * 1000
cur.execute("SELECT sum(etransfer)+sum(value)=1000*(SELECT count(*) FROM accounts) AS check_value FROM accounts;")
res = cur.fetchall()[0]
print res
cur.close()
con.close()
