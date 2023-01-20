#!/usr/bin/env bash

source test/init

plan tests 5
dir=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)

source "$dir/../openqa-label-known-issues-and-investigate-hook"
client_args=(api --host "$host_url")

export INVESTIGATE_FAIL=false
export INVESTIGATE_RETRIGGER_HOOK=false

# Mocking
openqa-trigger-bisect-jobs() {
    echo "openqa-trigger-bisect-jobs ($@)"
}
openqa-label-known-issues() {
    for testurl in $(cat - | sed 's/ .*$//'); do
        echo "[$testurl]($testurl): Unknown issue, to be reviewed -> $testurl/file/autoinst-log.txt"
    done
}
openqa-investigate() {
    "$INVESTIGATE_FAIL" && return 1
    "$INVESTIGATE_RETRIGGER_HOOK" && return 142
    for testurl in $(cat - | sed 's/ .*$//'); do
        echo "$testurl | openqa-investigate"
    done
}

try hook 123
is "$rc" 0 'successful hook'

has "$got" 'https://openqa.opensuse.org/tests/123 | openqa-investigate' 'correct output 1'
has "$got" 'openqa-trigger-bisect-jobs (--url https://openqa.opensuse.org/tests/123)' 'correct output 2'

export INVESTIGATE_FAIL=true
try hook 123
is "$rc" 1 'openqa-investigate failed'

export INVESTIGATE_FAIL=false
export INVESTIGATE_RETRIGGER_HOOK=true
try hook 123
is "$rc" 142 'openqa-investigate exit code for retriggering hook script'
