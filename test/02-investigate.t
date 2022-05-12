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
plan tests 10

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
is "$out" "unable to query job data for 42: " 'query error on stderr'

cli_rc=0
consider_parallel_and_directly_chained_clusters=1
out=$(clone 41 42 2>&1 > /dev/null) || rc=$?
is "$rc" 2 'fails when no jobs could be restarted'
is "$out" "unable to clone job 42: it is part of a parallel or directly chained cluster (not supported)" 'restart error on stderr'

openqa-cli() {
    if [[ "$1 $2" == "--json jobs/24" ]]; then
        echo '{"job": { "test": "vim", "priority": 50, "settings" : {} } }'
    elif [[ "$1 $2" == "--json jobs/27" ]]; then
        echo '{"job": { "test": "vim", "clone_id" : 28 } }'
    else
        echo '{"result": [{ "25": "foo", "26": "bar" }], "test_url": [{"25": "/tests/25", "26": "/tests/26"}] } '
    fi
}

rc=0
clone_call=echo
out=$(clone 23 24 2>&1 ) || rc=$?
is "$rc" 0 "Successful clone"
testlabel="vim:investigate"
is "$out" "* **$testlabel**: " "Expected markdown output of job urls for unsupported clusters"

rc=0
out=$(investigate 27 2>&1) || rc=$?
is "$rc" 0 'success regardless of actually triggered jobs'
is "$out" "Job already has a clone, skipping investigation. Use the env variable 'force=true' to trigger investigation jobs"

rc=0
out=$(force=true investigate 27 2>&1) || rc=$?
is "$rc" 0 'still success'
like "$out" "exclude_no_group is set, skipping investigation"
