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
plan tests 4

source openqa-investigate

cli_rc=1
openqa-cli() {
    return $cli_rc
}
client_call=openqa-cli

rc=0
out=$(clone 41 42  2>&1 > /dev/null) || rc=$?
is "$rc" 1 'fails when unable to query job data'
is "$out" "unable to query job data for 42: no response" 'query error on stderr'

cli_rc=0
consider_parallel_and_directly_chained_clusters=1
out=$(clone 41 42 2>&1 > /dev/null) || rc=$?
is "$rc" 2 'fails when no jobs could be restarted'
is "$out" "Unable to restart 42: no error message returned" 'restart error on stderr'
