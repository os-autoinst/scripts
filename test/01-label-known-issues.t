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
plan tests 19

source _common

client_output=''
mock-client() {
    client_output+="client_call $@"$'\n'
}

nl=$'\n'
client_call=(mock-client "${client_call[@]}")
logfile1=$dir/data/01-os-autoinst.txt.1
logfile2=$dir/data/01-os-autoinst.txt.2

rc=0
comment_on_job 123 Label || rc=$?
is "$rc" 0 'successful comment_on_job'
is "$client_output" "client_call -X POST jobs/123/comments text=Label$nl" 'comment_on_job works'

rc=0
search_log 123 'foo.*bar' "$logfile1" || rc=$?
is "$rc" 0 'successful search_log'

rc=0
search_log 123 'foo.*bar' "$logfile2" || rc=$?
is "$rc" 1 'failing search_log'

rc=0
output=$(search_log 123 'foo [z-a]' "$logfile2" 2>&1) || rc=$?
is "$rc" 2 'search_log with invalid pattern'
like "$output" 'range out of order in character class' 'correct error message'

rc=0
client_output=''
out=$logfile1
label_on_issue 123 'foo.*bar' Label 1 softfailed || rc=$?
expected="client_call -X POST jobs/123/comments text=Label
client_call -X POST jobs/123/restart
"
is "$rc" 0 'successful label_on_issue'
is "$client_output" "$expected" 'label_on_issue with restart and disabled force_result'

rc=0
client_output=''
out=$logfile1
enable_force_result=true label_on_issue 123 'foo.*bar' Label 1 softfailed || rc=$?
expected="client_call -X POST jobs/123/comments text=label:force_result:softfailed:Label

Label
client_call -X POST jobs/123/restart
"
is "$rc" 0 'successful label_on_issue'
is "$client_output" "$expected" 'label_on_issue with restart and force_result'

rc=0
client_output=''
out=$logfile1
label_on_issue 123 'foo.*bar' Label || rc=$?
expected="client_call -X POST jobs/123/comments text=Label
"
is "$rc" 0 'successful label_on_issue'
is "$client_output" "$expected" 'label_on_issue with restart and force_result'

rc=0
client_output=''
out=$logfile1
label_on_issue 123 'foo bar' Label || rc=$?
is "$rc" 1 'label_on_issue did not find search term'
is "$client_output" "" 'label_on_issue with restart and force_result'

mailx() {
    local s=$1 subject=$2 e=$3 header=$4 recv=$5
    local body='' line
    while read -r line; do
        body="$body NL $line"
    done
    echo "$subject,$header,$recv,$body" >&2
}
openqa-cli() {
    local id=$(basename "$4")
    cat "$dir/data/group$id.json"
}
from_email=foo@bar
client_args=(api --host http://localhost)
testurl=https://openqa.opensuse.org/api/v1/jobs/2291399
group_id=24
out=$(handle_unknown "$testurl" "$logfile1" "no reason" "$group_id" true "$from_email" 2>&1 >/dev/null) || true
like "$out" 'Unknown issue to be reviewed .Group 24.,openqa-label-known-issues <foo@bar>,dummy@example.com.dummy,' "mailx called like expected"
like "$out" '8<.*Backend process died.*>8' 'Log excerpt in mail'

out=$(handle_unknown "$testurl" "$logfile1" "no reason" "null" true "$from_email" 2>&1 >/dev/null) || true
is "$out" '' "mailx not called for group_id null"

group_id=25
out=$(handle_unknown "$testurl" "$logfile1" "no reason" "$group_id" true "$from_email" 2>&1 >/dev/null) || true
like "$out" '' "mailx not called for no email address and no fallback address"

notification_address=fallback@example.com
out=$(handle_unknown "$testurl" "$logfile1" "no reason" "$group_id" true "$from_email" "$notification_address" 2>&1 >/dev/null) || true
like "$out" 'Unknown issue to be reviewed .Group 25.,openqa-label-known-issues <foo@bar>,fallback@example.com' "mailx called like expected with fallback address"
