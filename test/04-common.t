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

source _common

success() {
    echo "SUCCESS $@"
}

failure() {
    warn "oh noe!"
    return 23
}

rc=0
output=$(runcli success a b c 2>&1) || rc=$?
is $rc 0 "runcli success"
is "$output" "SUCCESS a b c" "runcli successful output"

output=$(runcli failure a b c 2>&1) || rc=$?
is $rc 23 "runcli failure"
like "$output", "test/04-common.t.*failure a b c.*oh noe" "runcli failure output"

