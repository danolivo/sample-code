#!/usr/bin/env python

"""
	PostgreSQL cluster test
"""

import aws_provision
import os
import paramiko
import psycopg2
import sys
import time

clients_num = 200
heads_num = 20
use_private_address = False
pg_deploy = True
create_database = False
key_filename_path = "../.ssh/amazon_lepikhov.pem"

# Set environment
os.environ["PGDATABASE"] = "ubuntu"
os.environ["PGPORT"] = "5432"
os.environ["PGUSER"] = "shardman"
os.environ["PGPASSWORD"] = "shard12345"

aws_provision.parse_command_line()

# ##############################################################################
#
# Launch Shardman instances at AWS
#
# ##############################################################################

address = []
nodes = aws_provision.ShardmanInstances(aws_provision.SHARDMAN_NODES)
if (use_private_address):
    address = nodes.getPrivateAddress()
else:
    address = nodes.getPublicAddress()

# ##############################################################################
#
# Deploy Postgres
#
# ##############################################################################

# Wait for compute nodes accessibility
def WaitForConnection(ip):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    print("Connect to IP", ip)
    while (True):
        try:
            client.connect(hostname=ip, username=os.environ["PGDATABASE"], key_filename=key_filename_path)
        except paramiko.ssh_exception.NoValidConnectionsError:
            print("Try to connect to the server.")
            time.sleep(1)
            continue
        except paramiko.ssh_exception.SSHException:
            print("Catch SSHException. Try to reconnect to the server.")
            time.sleep(1)
            continue
        except:
            print("Unexpected error:", sys.exc_info()[0])
            raise
        # Exit if connection established
        break
    return client

if (pg_deploy):
    create_database = True
    # Establish ssh connections
    clients = []
    for ip in address:
        clients.append(WaitForConnection(ip))

    # Launch PG in parallel
    stdouts = []
    for client in clients:
        stdin, stdout, stderr = client.exec_command('cd pg && \
            	. ../scripts/paths.sh && \
            	../scripts/pgc && \
            	../scripts/mk && \
            	../scripts/pre')
        stdouts.append(stdout)

    nclient = 0
    for stdout in stdouts:
        stdout.channel.recv_exit_status()
        nclient += 1
        print("End of launch of client {0:d}/{1:d}".format(nclient,len(clients)))

    for client in clients:
        client.close()
    print("End of postgres deploying")
else:
    print("Skip deploying of the postgres")

# ##############################################################################
#
# Create database
#
# ##############################################################################

if (create_database):
    conns = []
    curs = []

    for node in address:
        con = psycopg2.connect(host=node)
        con.autocommit = True
        cur = con.cursor()
        conns.append(con)
        curs.append(cur)

        cur.execute(" \
            DROP SCHEMA IF EXISTS shardman CASCADE; \
            DROP TABLE IF EXISTS accounts CASCADE; \
            DROP TABLE IF EXISTS companies CASCADE; \
        ")

        cur.execute(" \
            CREATE TABLE accounts ( \
                aid bigserial, \
                name text, \
                value bigint, \
                etransfer bigint, \
                itransfer bigint, \
	        net bigint DEFAULT 0, \
	        nit bigint DEFAULT 0 \
            ) PARTITION BY hash (aid);")

    NodesNum = len(curs)
    for n in range(NodesNum):
        cur = curs[n]
        remoteNum = 0
        for i in range(NodesNum):
            print("[{2:d}/{3:d}] Create partition for server {0:d} on server {1:d}".format(n, i, n*NodesNum+i+1, NodesNum*NodesNum))
            if (i == n):
                cur.execute("CREATE TABLE accounts_" + str(i) + \
                    " PARTITION OF accounts FOR VALUES WITH (modulus "+ str(NodesNum) + \
                    ", remainder " + str(i) + ");")
            else:
                cur.execute("CREATE SERVER IF NOT EXISTS remote" + str(remoteNum) + \
                	" FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '" + address[i] + \
                	"', use_remote_estimate 'on');")
                cur.execute("CREATE USER MAPPING IF NOT EXISTS FOR PUBLIC SERVER remote" + str(remoteNum) + ";")
                cur.execute("CREATE FOREIGN TABLE accounts_" + str(i) + \
                            " PARTITION OF accounts FOR VALUES WITH (modulus " + str(NodesNum) + \
                            ", remainder " + str(i) + ") SERVER remote" + str(remoteNum) + ";")
                remoteNum += 1

    print("Fill the table...")
    curs[0].execute("explain analyze verbose INSERT INTO accounts (name, value, etransfer, itransfer) \
        SELECT 'Name' || gs.*::text, 1000, 0, 0 FROM generate_series(1, 1e3) AS gs")

    print("Create indexes...")
    for cur in curs:
        cur.execute("CREATE INDEX ind1 ON accounts (aid);")
        cur.close()

    for con in conns:
        con.close()

# ##############################################################################
#
# Execute pgbench test
#
# ##############################################################################

pids = []
for addr in address:
    pid = os.fork()

    if (pid == 0):
        os.system("pgbench -n -P 5 -c " + str(clients_num / heads_num) + " -j " + str(clients_num / heads_num) + " --max-tries 1000 -f test.pgb -T 60 -h " + str(addr))
        sys.exit(0)

    print("pid: ", pid, ", addr: ", addr)
    pids.append(pid)

for pid in pids:
    os.waitpid(pid, 0)

# ##############################################################################
#
# Show data and test consistency markers
#
# ##############################################################################

#con = psycopg2.connect(host=address[1])
#cur = con.cursor()
#cur.execute("SELECT (itp > 4 AND itp < 6) AS int_transfer_percentage \
#	FROM (SELECT 100*sum(nit)/sum(net) AS itp FROM accounts) AS pr;")
#res = cur.fetchall()[0]
#print(res)
# Sum of total current value and external transfers must be equal to <accounts number> * 1000
#cur.execute("SELECT sum(etransfer)+sum(value)=1000*(SELECT count(*) FROM accounts) AS check_value FROM accounts;")
#res = cur.fetchall()[0]
#print(res)
#cur.close()
#con.close()

