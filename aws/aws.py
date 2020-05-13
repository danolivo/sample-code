#!/usr/bin/env python

"""
	Provision AWS EC2 instances
"""

import json
import os
import paramiko
import psycopg2
import sys
import time
import getopt

# AWS instance type wil be used
#DefaultInstanceType="c4.2xlarge" # 8 vCPUs, 16 GB RAM
DefaultInstanceType = "t2.medium" # 2 vCPUs, 4 GB RAM
#DefaultInstanceType = "t2.micro" # 1 vCPUs, 1 GB RAM
NodesNum = 3
AWSCommandsOutput = " > /dev/null"

class ShardmanInstances(object):
    def __init__(self, nnodes, instanceType=DefaultInstanceType, imageId="ami-0ec4e716f9b2db25b", dropRemote=False):
        """ Load shardman instances. Initialization will be finished when all
        nnodes instances will be in 'running' state. If we have stopped instances,
        run needed quantity.
        If nnodes == 0, wait for transient states and load current state without
        launching or creating anything.
        
        AWS instance states: pending, running, shutting-down, terminated, stopping, stopped
        """
        self.instanceType = instanceType
        self.dropRemote = dropRemote
        self.imageId = imageId
        self.GetAWSNodesCmdline = "aws ec2 describe-instances --filters 'Name=tag:group,Values=shardman' " + AWSCommandsOutput
        self.nnodes = 0

        # Wait for transient AWS instances.
        self.waitTransientNodes()

        # Launch instances at the stopped state
        with open('nodelist.txt') as json_file:
            instancesDesc = json.load(json_file)
            stopped_nodes = 0
            total_stopped_nodes = 0

            for I in instancesDesc["Reservations"]:
                if (nnodes == 0):
                    # Calculate number of running nodes and don't execute anyone else.
                    if (I["Instances"][0]["State"]["Name"] == "running"):
                        self.nnodes += 1
                    continue

                if (I["Instances"][0]["State"]["Name"] == "running"):
                    # if number of nodes is mpre than needed, stop redundant
                    if (self.nnodes == nnodes):
                        instanceId = I["Instances"][0]["InstanceId"]
                        print("Stop excess instance: ", instanceId)
                        os.system("aws ec2 stop-instances --instance-ids " + instanceId + AWSCommandsOutput)
                        continue

                    self.nnodes += 1
                elif (I["Instances"][0]["State"]["Name"] == "stopped"):
                    instanceId = I['Instances'][0]['InstanceId']
                    total_stopped_nodes += 1
                    if (self.nnodes < nnodes):
                        os.system("aws ec2 start-instances --instance-ids " + instanceId + AWSCommandsOutput)
                        self.nnodes += 1
                        stopped_nodes += 1

            if (nnodes == 0):
                self.instances = instancesDesc["Reservations"]
                print("Load {0:d} currently running instances".format(self.nnodes))
                return

            if (self.nnodes > 0):
                print("{0:d}/{1:d} stopped nodes had been reused".format(stopped_nodes, total_stopped_nodes))

            # Add new nodes, if needed
            while (self.nnodes < nnodes):
                self.provisionAWSInstance()
                self.nnodes += 1

        # Wait for launching instances
        self.waitTransientNodes()

        # Sanity check
        with open('nodelist.txt') as json_file:
            instancesDesc = json.load(json_file)
            cstates = ["stopped", "running", "terminated"]
            for I in instancesDesc["Reservations"]:
                state = I["Instances"][0]["State"]["Name"]
                if (state not in cstates):
                    raise Exception("Instance in incorrect state: ", state, "InstanceId: ", I['Instances'][0]['InstanceId'])

        self.instances = instancesDesc["Reservations"]
        print("Shardman provisioning finished. nodes: ", self.nnodes)

    def checkTransientNodes(self, instances):
        """ See for AWS instances in transient state. Return number of such instances. """
        tstates = ["pending", "shutting-down", "stopping"]
        count = 0

        for I in instances:
            if (I["Instances"][0]["State"]["Name"] in tstates):
                count += 1

        return count

    def getPrivateAddress(self):
        address = []
        for i in self.instances:
            if (i["Instances"][0]["State"]["Name"] != "running"):
                continue
            address.append(i["Instances"][0]["PrivateIpAddress"])
        return address

    def getPublicAddress(self):
        address = []
        for i in self.instances:
            if (i["Instances"][0]["State"]["Name"] != "running"):
                continue
            address.append(i["Instances"][0]["PublicIpAddress"])
        return address

    def excludeTerminated(self, instances):
        new_instances = []
        
        for i in instances:
            if (i["Instances"][0]["State"]["Name"] != "terminated"):
                new_instances.append(i)
        return new_instances

    def waitTransientNodes(self):
        """
        Side effect: updates self.instances.
        """
        while (True):
            os.system(self.GetAWSNodesCmdline + " > nodelist.txt")

            with open('nodelist.txt') as json_file:
                instances = self.excludeTerminated(json.load(json_file)["Reservations"])
                count = self.checkTransientNodes(instances)

                if (count == 0):
                    self.instances = instances
                    break

                print("Wait for {0:d} instance(s) in transient state".format(count))
                time.sleep(5)

    def provisionAWSInstance(self):
        os.system("aws ec2 run-instances --instance-type " + self.instanceType + \
            " --image-id " + self.imageId + " --key-name amazon_lepikhov --security-groups Shardman \
            --tag-specifications 'ResourceType=instance,Tags=[{Key=group,Value=shardman}]'" + AWSCommandsOutput)

    def show(self):
        try:
            instances = self.instances
            print("--- Shardman nodes ---")
            for i in instances:
                if (i["Instances"][0]["State"]["Name"] == "terminated"):
                    continue
                try:
                    if (i["Instances"][0]["State"]["Name"] == "running"):
                        pubIP = i["Instances"][0]["PublicIpAddress"]
                        prvIP = i["Instances"][0]["PrivateIpAddress"]
                    else:
                        pubIP = "-.-.-.-"
                        prvIP = "-.-.-.-"

                    print("Public IP: ", pubIP, "Private IP: ", prvIP, "State: ", i["Instances"][0]["State"]["Name"])
                except KeyError:
                    print("Instance do not have a key. ", sys.exc_info()[0])
                    raise
            print("-----------------------")

        except AttributeError:
            print(str(err))
            print("Instances of shardman is not loaded or null.")
            return

    def stop(self):
        print("Stop all shardman nodes...")
        self.waitTransientNodes()
        running = 0
        stopped = 0

        for i in self.instances:
            if (i["Instances"][0]["State"]["Name"] == "running"):
                os.system("aws ec2 stop-instances --instance-ids " + i["Instances"][0]["InstanceId"] + AWSCommandsOutput)
                running += 1
            elif (i["Instances"][0]["State"]["Name"] == "stopped"):
                stopped += 1

        self.waitTransientNodes()
        print("Stop ", running, " instances. ", stopped, " had been stopped earlier.")

    def clear(self):
        """ Remove all nodes (running and stopped) """
        terminated_ids = ""
        for i in self.instances:
            id = i["Instances"][0]["InstanceId"]
            if (i["Instances"][0]["State"]["Name"] == "running"):
                terminated_ids += id
                terminated_ids += " "
            # Delete stopped instances
            if (i["Instances"][0]["State"]["Name"] == "stopped"):
                os.system("aws ec2 terminate-instances --instance-ids " + id + AWSCommandsOutput)

        if (terminated_ids != ""):
            os.system("aws ec2 terminate-instances --instance-ids " + terminated_ids + AWSCommandsOutput)
        else:
            print("No instances specified")

        self.waitTransientNodes()

def usage():
    print("Script parameters: ")
    print("-n nnodes. Set number of instances to be launching. If nnodes < 0 or"
        " nothing, load current state of shardman nodes (running and stopped)")

SHARDMAN_NODES = 0
AWS_OPERATION = "show"

def parse_command_line():
    global SHARDMAN_NODES, AWS_OPERATION
    try:
        opts, args = getopt.getopt(sys.argv[1:], "hn:c:", ["--command"])
    except getopt.GetoptError as err:
        # print help information and exit:
        print(str(err))
        usage()
        sys.exit(2)
    output = None
    verbose = False
    for opt, arg in opts:
        if opt == "-n":
            SHARDMAN_NODES = int(arg)
        elif opt in ("-h", "--help"):
            usage()
            sys.exit()
        elif opt in ("-c", "--command"):
            # command type
            AWS_OPERATION = arg
        else:
            assert False, "unhandled option"

additional_gucs = []

# Wait for compute nodes accessibility
def WaitForConnection(ip):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    print("Connect to IP", ip)
    while (True):
        try:
            client.connect(hostname=ip, username=os.environ["PGDATABASE"], key_filename=os.environ["AWS_KEY_FILE"])
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

if __name__ == "__main__":
    parse_command_line()

    if (SHARDMAN_NODES == 0):
        print("Use existed shardman instances.")
    else:
        print("Start AWS provisioning of shardman")

    i = ShardmanInstances(SHARDMAN_NODES)

    if (AWS_OPERATION == "show"):
        i.show()
        exit(0)
    elif (AWS_OPERATION == "clear"):
        i.clear()
    elif (AWS_OPERATION == "stop"):
        i.stop()

    print("End of provisioning")

