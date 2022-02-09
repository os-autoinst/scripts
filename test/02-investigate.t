#!/usr/bin/env bash

set -e

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)

TEST_MORE_PATH=$dir/../test-more-bash
BASHLIB="`
    find $TEST_MORE_PATH -type d |
    grep -E '/(bin|lib)$' |
    xargs -n1 printf "%s:"`"
PATH=$BASHLIB$PATH

source bash+ :std
use Test::More
plan tests 6

host=localhost
url=https://localhost

source openqa-investigate

client_args=()
cli_rc=1
openqa-cli() {
    return $cli_rc
}
client_call=(openqa-cli)

rc=0
out=$(clone 41 42  2>&1 > /dev/null) || rc=$?
is "$rc" 1 'fails when unable to query job data'
is "$out" "unable to query job data for 42: no response" 'query error on stderr'

cli_rc=0
out=$(clone 41 42 2>&1 > /dev/null) || rc=$?
is "$rc" 2 'fails when no jobs could be restarted'
is "$out" "Unable to restart 42: no error message returned" 'restart error on stderr'

openqa-cli() {
    if [[ "$1 $2" == "--json jobs/24" ]]; then
        echo '{"job": { "test": "vim", "priority": 50, "settings" : {} } }'
    else
        echo '{"result": [{ "25": "foo", "26": "bar" }], "test_url": [{"25": "/tests/25", "26": "/tests/26"}] } '
    fi
}

rc=0
out=$(clone 23 24 2>&1 ) || rc=$?
is "$rc" 0 "Successful clone"
testlabel="vim:investigate"
is "$out" "* **$testlabel**: $url/t25"$'\n'"* **$testlabel**: $url/t26" "Expected markdown output of job urls"
