#!/bin/bash

# ##############################################################################
#
# Update postgres repository on each AWS shardman node and set to particular
# commit.
# Use jq to parse the JSON string. (sudo apt install jq)
#
# ##############################################################################

# Get all running nodes with the shardman tag.
jinstances=$(aws ec2 describe-instances --filters 'Name=tag:group,Values=shardman' "Name=instance-state-name,Values=running")

ninstances=0
ips=()
#statename=$(echo $jinstances | jq ".Reservations[$ninstances].Instances[0].State.Name")
#    echo "statename: ", $statename
#    exit
while (true); do
    statename=$(echo $jinstances | jq ".Reservations[$ninstances].Instances[0].State.Name")
    ip=$(echo $jinstances | jq ".Reservations[$ninstances].Instances[0].PublicIpAddress")

    if [ "$statename" == "null" ]; then
        break
    fi

    ninstances=$((ninstances+1))
    ips[${#ips[*]}]=$ip
    echo "[$ninstances]: IP $ip, state $statename"
done

echo "Total number of instances: " $ninstances

for i in ${ips[@]}; do
    node=$(last -i | head -n 1 | awk "{print $i}")
    echo "PPROCESS NODE " $node
    ssh -i ~/.ssh/amazon_lepikhov.pem ubuntu@$node "cd pg && git checkout master && git pull && git checkout $1"
    ssh -i ~/.ssh/amazon_lepikhov.pem ubuntu@$node "export LC_ALL='C' && cd pg && ../scripts/pgc > /dev/null && ../scripts/mk && ../scripts/pre"
done