#!/usr/bin/env bash

source test/init

plan tests 25

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

send-email() {
    local mailto=$1 email=$2
    echo "$mailto" >&2
    echo "$email" >&2
}
openqa-cli() {
    local id=$(basename "$4")
    cat "$dir/data/group$id.json"
}
from_email=foo@bar
client_args=(api --host http://localhost)
testurl=https://openqa.opensuse.org/api/v1/jobs/2291399
group_id=24
job_data='{"job": {"name": "foo", "result": "failed"}}'
out=$(handle_unknown "$testurl" "$logfile1" "no reason" "$group_id" true "$from_email" "" "$job_data" 2>&1 >/dev/null) || true
like "$out" 'Subject: Unreviewed issue .Group 24 openQA.' "send-email subject like expected"
like "$out" 'From: openqa-label-known-issues <foo@bar>' "send-email from called like expected"
like "$out" 'To: dummy@example.com.dummy' "send-email to like expected"
like "$out" '8<.*Backend process died.*>8' 'Log excerpt in mail'
like "$out" 'Content-Type: text/html' 'mail has text part'
like "$out" 'Content-Type: text/plain' 'mail has HTML part'
like "$out" '<li>Name: foo' 'mail contains job name'

out=$(handle_unknown "$testurl" "$logfile1" "no reason" "null" true "$from_email" 2>&1 >/dev/null) || true
is "$out" '' "send-email not called for group_id null"

group_id=25
out=$(handle_unknown "$testurl" "$logfile1" "no reason" "$group_id" true "$from_email" 2>&1 >/dev/null) || true
like "$out" '' "send-email not called for no email address and no fallback address"

notification_address=fallback@example.com
out=$(handle_unknown "$testurl" "$logfile1" "no reason" "$group_id" true "$from_email" "$notification_address" "$job_data" 2>&1 >/dev/null) || true
like "$out" 'To: fallback@example.com' "send-email to like expected"
like "$out" 'Subject: Unreviewed issue .Group 25 Lala.' "send-email subject like expected"
