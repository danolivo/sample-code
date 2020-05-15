#!/usr/bin/env python

"""
	GIT operations on shardman instances
"""

import aws
import getopt
import os
import paramiko
import sys

COMMIT = "none"

os.environ["SSHUSER"] = "ubuntu"
os.environ["AWS_KEY_FILE"] = os.environ["HOME"] + "/.ssh/amazon_lepikhov.pem"

def parse_command_line():
    global COMMIT
    try:
        opts, args = getopt.getopt(sys.argv[1:], "c:")
    except getopt.GetoptError as err:
        # print help information and exit:
        print(str(err))
        sys.exit(2)
    for opt, arg in opts:
        if opt == "-c":
            COMMIT = arg
        else:
            assert False, "unhandled option"

# ##############################################################################
#
# Launch Shardman instances at AWS
#
# ##############################################################################

address = []
parse_command_line()

if (COMMIT == "none"):
    print("No commit set")
    sys.exit(0)

nodes = aws.ShardmanInstances(0) # Use existed nodes
address = nodes.getPublicAddress()

clients = []
for ip in address:
    clients.append(aws.WaitForConnection(ip))

# Launch PG in parallel
stdouts = []
for client in clients:
    stdin, stdout, stderr = client.exec_command('cd pg && \
        . ../scripts/paths.sh && \
        git pull && \
        git checkout ' + COMMIT + ' && \
        ../scripts/pgc && \
        ../scripts/mk && \
        ../scripts/pre')
    stdouts.append(stdout)

nclient = 0
for stdout in stdouts:
    stdout.channel.recv_exit_status()
    nclient += 1
    print("End of wait for client {0:d}/{1:d}".format(nclient, len(clients)))
    print(stdout.read(), " | ", stderr.read())

for client in clients:
    client.close()
print("End of git task")