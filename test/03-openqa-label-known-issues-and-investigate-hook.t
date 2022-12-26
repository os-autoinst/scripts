#!/usr/bin/env bash

source test/init

plan tests 5

try script_dir=$dir/scripts ./openqa-label-known-issues-and-investigate-hook 123
is "$rc" 0 'successful hook'

like "$got" 'https://openqa.opensuse.org/tests/123 | openqa-investigate' 'correct output 1'
like "$got" 'openqa-trigger-bisect-jobs .--url https://openqa.opensuse.org/tests/123.' 'correct output 2'

export INVESTIGATE_FAIL=true
try script_dir=$dir/scripts ./openqa-label-known-issues-and-investigate-hook 123
is "$rc" 1 'openqa-investigate failed'

export INVESTIGATE_FAIL=false
export INVESTIGATE_RETRIGGER_HOOK=true
try script_dir=$dir/scripts ./openqa-label-known-issues-and-investigate-hook 123
is "$rc" 142 'openqa-investigate exit code for retriggering hook script'
