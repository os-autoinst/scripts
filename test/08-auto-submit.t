#!/usr/bin/env bash

source test/init

plan tests 5

source _common

mock_osc() {
    local cmd=$1
    local args=(${@:2})
    if [[ $cmd == 'request' && ${args[0]} == 'list' ]]; then
        _request_list
    fi
}

_request_list() {
    echo "Created by: foo"
}

osc=mock_osc

source os-autoinst-obs-auto-submit

diag "########### has_pending_submission"

throttle_days=0
try has_pending_submission
is "$rc" 0 "returns 0 with throttle_days=0"

throttle_days=1
try has_pending_submission
is "$rc" 1 "returns 1 with existing SRs"
like "$got" "Created by: foo" "expected output"

_request_list() {
    echo ""
}
try has_pending_submission
is "$rc" 0 "returns 0 without existing SRs"
is "$got" "" "no output"
