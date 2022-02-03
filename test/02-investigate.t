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
plan tests 2

source openqa-investigate

cli_rc=1
openqa-cli() {
    return $cli_rc
}

rc=0
clone 41 42 || rc=$?
is "$rc" 1 'fails when unable to query job data'

cli_rc=0
clone 41 42 || rc=$?
is "$rc" 2 'fails when no jobs could be restarted'
