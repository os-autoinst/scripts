#!/bin/bash
found_machines=0
while read -r fqdn; do
    ping -c1 -W1 "${fqdn}" &> /dev/null && echo "${fqdn} up" && found_machines=$((found_machines + 1))
done <<< $(python3 get_unused_machines.py)
exit $((found_machines > 0))
