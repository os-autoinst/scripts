#!/bin/bash
set -euo pipefail
found_machines=0
output=$(python3 get_unused_machines.py)
while read -r fqdn; do
    ping -c1 -W1 "${fqdn}" &> /dev/null && echo "${fqdn} up" && found_machines=$((found_machines + 1))
done <<< "$output"
exit $((found_machines > 0))
