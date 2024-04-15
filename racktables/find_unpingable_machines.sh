#!/bin/bash
python3 get_unused_machines.py | while read fqdn; do
    ping -c1 -W1 "${fqdn}" &> /dev/null && echo "${fqdn} up"
done
