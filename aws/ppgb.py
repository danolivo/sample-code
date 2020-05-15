#!/usr/bin/env python

"""
	AWS. Execute the pgbench test
"""

import json
import os
import subprocess # execute shell scripts
import sys
import psycopg2
import aws

total_time = 10 # pgbench test time
clients_num = 200
coordinators_num = -1 # Use all instances as heads
use_private_address = False


#additional_gucs = ["track_global_snapshots=false", "autoprepare_limit=0", "autoprepare_memory_limit=0", "shared_buffers=1GB"]
additional_gucs = ["track_global_snapshots=true",
                    "autoprepare_limit=-1",
                    "autoprepare_memory_limit=-1",
                    "shared_buffers=1GB",
                    "postgres_fdw.use_global_snapshots=true",
                    "max_prepared_transactions=1000"]


# Set environment
os.environ["PGDATABASE"] = "ubuntu"
os.environ["PGPORT"] = "5432"
os.environ["PGUSER"] = "shardman"
os.environ["PGPASSWORD"] = "shard12345"
os.environ["AWS_KEY_FILE"] = os.environ["HOME"] + "/.ssh/amazon_lepikhov.pem"

nodesnum = 0
publicIP = []
privateIP = []

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

        publicIP.append(c["Instances"][0]["PublicIpAddress"])
        privateIP.append(c["Instances"][0]["PrivateIpAddress"])
        nodesnum += 1

if (nodesnum == 0):
    print("No one node found")
    sys.exit(1)

if (coordinators_num < 0 or coordinators_num > nodesnum):
    coordinators_num = nodesnum

print("Total nodes in shardman: ", nodesnum)
for i in range(nodesnum):
    print(i, " ",  publicIP[i], " ", privateIP[i])

if (use_private_address):
    address = privateIP
else:
    address = publicIP
# ##############################################################################
#
# Set additional GUCs
#
# ##############################################################################

if (len(additional_gucs) > 0):
    print("SET additional GUC's")

    # Establish ssh connections
    clients = []
    for ip in address:
        clients.append(aws.WaitForConnection(ip))

    # Set additional GUC's
    stdouts = []
    opts=""
    for guc in additional_gucs:
        opts += " -c " + guc

    print("SET " + opts)
    for client in clients:
        stdin, stdout, stderr = client.exec_command(
            "cd pg && . ../scripts/paths.sh && \
            env PGUSER=" + os.environ['PGUSER'] + \
            " PGPASSWORD='" + os.environ['PGPASSWORD'] + \
            "' pg_ctl -o '" + opts + "' -l logfile.log -D PGDATA restart")
    stdouts.append(stdout)

    for stdout in stdouts:
        stdout.channel.recv_exit_status()

    for client in clients:
        client.close()
    print("End of the instances GUC's changing")

# ##############################################################################
#
# Execute test
#
# ##############################################################################

pids = []
debugmsg = False

for addr in address:
    pid = os.fork()

    if (pid == 0):
        cmdline = "pgbench -n -P 5 -c " + str(int(clients_num/coordinators_num)) + \
            " -U " + os.environ["PGUSER"] + \
            " -j " + str(int(clients_num/coordinators_num)) + \
            " --max-tries 1000 -f test.pgb -T " + str(total_time) +  \
            " -h " + str(addr)

        if (not debugmsg):
            debugmsg = True
            print("DEBUG pgbench string sample: ", cmdline)

        os.system(cmdline)
        os._exit(0)

    print("pid: ", pid, ", addr: ", addr)
    pids.append(pid)

for pid in pids:
    os.waitpid(pid, 0)

# ##############################################################################
#
# Show data and test consistency markers
#
# ##############################################################################

con = psycopg2.connect(host=address[1])
cur = con.cursor()
cur.execute("SELECT (itp > 4 AND itp < 6) AS int_transfer_percentage \
	FROM (SELECT 100*sum(nit)/sum(net) AS itp FROM accounts) AS pr;")
res = cur.fetchall()[0]
print(res)
# Sum of total current value and external transfers must be equal to <accounts number> * 1000
cur.execute("SELECT sum(etransfer)+sum(value)=1000*(SELECT count(*) FROM accounts) AS check_value FROM accounts;")
res = cur.fetchall()[0]
print(res)
cur.close()
con.close()
