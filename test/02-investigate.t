#!/usr/bin/env bash

source test/init
bpan:source bashplus +err +fs +sym

plan tests 46

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
is "$out" "Unable to clone job 42: it is part of a directly chained cluster (not supported)" 'restart error on stderr'

openqa-cli() {
    if [[ "$1 $2" == "--json jobs/24" ]]; then
        echo '{"job": { "test": "vim", "priority": 50, "settings" : {} } }'
    elif [[ "$1 $2" == "--json jobs/27" ]]; then
        echo '{"job": { "test": "vim", "clone_id" : 28 } }'
    elif [[ "$1 $2" == "--json jobs/33" ]]; then
        echo '{"job": { "test": "vim", "test": "vim:investigate:abc", "result": "failed" } }'
    elif [[ "$1 $2" == "--json jobs/34" ]]; then
        echo '{"job": { "test": "vim:investigate:retry", "result": "failed", "settings": {"OPENQA_INVESTIGATE_ORIGIN": "35"} } }'
    elif [[ "$1 $2" == "--json jobs/35" ]]; then
        echo '{"job": { "test": "vim:investigate:retry", "result": "passed", "settings": {"OPENQA_INVESTIGATE_ORIGIN": "35"} } }'
    elif [[ "$1 $2" == "--json jobs/36" ]]; then
        echo '{"job": { "test": "vim:investigate:retry", "result": "softfailed", "settings": {"OPENQA_INVESTIGATE_ORIGIN": "35"} } }'
    elif [[ "$2" =~ experimental/jobs/3400[12]/status ]]; then
        echo '{ "state": "done", "test": "vim:investigate:retry", "result": "failed" }'
    elif [[ "$2" =~ experimental/jobs/3400[34]/status ]]; then
        echo '{ "state": "done", "test": "vim:investigate:retry", "result": "passed" }'
    elif [[ $@ == "-X POST jobs/30/comments text=Starting investigation for job 31" ]]; then
        echo '{"id": 1234}'
    elif [[ $@ == $'-X PUT jobs/30/comments/1234 text=Automatic investigation jobs for job 31:\n\nfoo' ]]; then
        echo true > "$comment_1234_updated"
    elif [[ $@ == '-X DELETE jobs/30/comments/1234' ]]; then
        echo true > "$comment_1234_deleted"
    elif [[ $@ == $'-X POST jobs/31/comments text=Automatic investigation jobs for job 31:\n\nfoo' ]]; then
        echo true > "$comment_for_job_31_created"
    elif [[ $@ == "-X GET jobs/30/comments" ]]; then
        echo '[{"id": 1234, "text":"Starting investigation for 31"},{"id": 1235, "text":"unrelated comment"}]'
    elif [[ $@ == "-X POST jobs/32/comments text=Starting investigation for job 32" ]]; then
        echo '{"id": 1237}'
    elif [[ $@ == "-X GET jobs/32/comments" ]]; then
        echo '[{"id": 1236, "text":"Starting investigation for job 32"},{"id": 1237, "text":"Starting investigation for job 32"}]'
    elif [[ $@ == "-X GET jobs/35/comments" ]]; then
        echo '[{"id": 1236, "text":"Automatic investigation jobs for job\n**a:investigate:retry**:url/t34001\n**a:investigate:last_good_tests:coffee**:url/t34002\n**a:investigate:last_good_build:2001**:url/t34003\n**a:investigate:last_good_tests_and_build:coffee+2001**:url/t34004"}]'
    elif [[ $@ =~ "-X POST jobs/35/comments" ]]; then
        warn "Commenting 35 ($@)"
        exit 99
    elif [[ $@ == '--apibase  --json tests/27/dependencies_ajax' ]]; then
        echo '{"cluster":{}, "edges":[], "nodes":[{"id":27,"state":"done","result":"passed"}]}'
    elif [[ $@ == '--apibase  --json tests/28/dependencies_ajax' ]]; then
        echo '{"cluster":{}, "edges":[], "nodes":[{"id":28,"state":"done","result":"failed"}]}'
    elif [[ $@ == '--apibase  --json tests/33/dependencies_ajax' ]]; then
        echo '{"cluster":{}, "edges":[], "nodes":[]}'
    elif [[ $@ == '--apibase  --json tests/29/dependencies_ajax' ]]; then
        echo '{"cluster":{"cluster_foo":[28],"cluster_bar":[29]}, "edges":[], "nodes":[{"id":28,"state":"done","result":"failed"},{"id":29,"state":"done","result":"passed"}]}'
    elif [[ $@ == '--apibase  --json tests/30/dependencies_ajax' ]]; then
        echo '{"cluster":{"cluster_foo":[28,30],"cluster_bar":[29]}, "edges":[], "nodes":[{"id":28,"state":"uploading","result":"none"},{"id":30,"state":"done","result":"passed"}]}'
    elif [[ $@ == '--apibase  --json tests/32/dependencies_ajax' ]]; then
        echo '{"cluster":{"cluster_foo":[28,32],"cluster_bar":[29]}, "edges":[], "nodes":[{"id":28,"state":"cancelled","result":"none"},{"id":32,"state":"done","result":"failed"},{"id":29,"state":"running","result":"running"}]}'
    elif [[ $@ == '--apibase  --json tests/31/dependencies_ajax' ]]; then
        # job with cancelled job in the cluster (should be treated like a done job)
        echo '{"cluster":{"cluster_foo":[28,31],"cluster_bar":[29]}, "edges":[], "nodes":[{"id":28,"state":"cancelled","result":"none"},{"id":31,"state":"done","result":"failed"}]}'
    else
        echo '{"result": [{ "25": "foo", "26": "bar" }], "test_url": [{"25": "/tests/25", "26": "/tests/26"}] } '
    fi
}

clone_call=echo
_clone_call() {
    echo "$@" >&2
}
clone_call=_clone_call
try clone 23 24
is "$rc" 0 "Successful clone"
testlabel="vim:investigate"
has "$got" "* **$testlabel**: " "Expected markdown output of job urls for unsupported clusters"
has "$got" '_TRIGGER_JOB_DONE_HOOK=1' "job is cloned with _TRIGGER_JOB_DONE_HOOK"

clone_call=echo
try investigate 27
is "$rc" 0 'success regardless of actually triggered jobs'
is "$got" "Job 27 already has a clone, skipping investigation. Use the env variable 'force=true' to trigger investigation jobs"

try force=true investigate 28
is "$rc" 0 'still success when job is skipped (because of exclude_no_group)'
has "$got" "exclude_no_group is set, skipping investigation"

try investigate 30
is "$rc" 142 'investigation postponed because other job in cluster is not done'
is "$got" "Postponing to investigate job 30: waiting until 1 pending parallel job(s) finished"

try main 30
is "$rc" 142 'return code (for postponing) passed by main function'
is "$got" "Postponing to investigate job 30: waiting until 1 pending parallel job(s) finished" 'output passed by main function'

try investigate 32
is "$rc" 0 'investigation not postponed if other job in dependency tree not done but cluster itself is done'

try force=true investigate 31
is "$rc" 0 'success when job is skipped (because of exclude_no_group and job w/o group)'
has "$got" 'Job w/o job group, $exclude_no_group is set, skipping investigation'

try investigate 33
is "$rc" 0 'success (33)'
has "$got" "Job is ':investigate:' already, skipping investigation" "skip :investigate: (33)"

try investigate 34
is "$rc" 2 'mocked function returned failure (34)'
has "$got" "Commenting 35" "Posting comment on OPENQA_INVESTIGATE_ORIGIN (34)"
has "$got" "likely not a sporadic" "not sporadic (34)"
has "$got" "product issue" "product issue (34)"

test-post-investigate() {

    t1="fail"

    t2="passed" t3="passed" t4="passed"
    fetch-investigation-results() {
        echo "retry|1|$t1
last_good_tests|2|$t2
last_good_build|3|$t3
last_good_tests_and_build|4|$t4"
    }
    product_issue=false
    is-product-issue 34
    is "$product_issue" "false" "$t1+$t2+$t3+$t4 -> false"

    t2="fail" t3="passed" t4="passed"
    is-product-issue 34
    is "$product_issue" "true" "$t1+$t2+$t3+$t4 -> true"

    t2="fail" t3="fail" t4="passed"
    is-product-issue 34
    is "$product_issue" "false" "$t1+$t2+$t3+$t4 -> false"

    t2="" t3="passed" t4="passed"
    is-product-issue 34
    is "$product_issue" "true" "$t1+$t2+$t3+$t4 -> true"

    t2="" t3="passed" t4=""
    is-product-issue 34
    is "$product_issue" "true" "$t1+$t2+$t3+$t4 -> true"

    t2="fail" t3="" t4="fail"
    is-product-issue 34
    is "$product_issue" "false" "$t1+$t2+$t3+$t4 -> false"


    try investigate 35
    is "$rc" 2 'mocked function returned failure (35)'
    has "$got" "Commenting 35" "Posting comment on OPENQA_INVESTIGATE_ORIGIN (35)"
    has "$got" "likely a sporadic" "sporadic (35)"

    try investigate 36
    is "$rc" 2 'mocked function returned failure (36)'
    has "$got" "Commenting 35" "Posting comment on OPENQA_INVESTIGATE_ORIGIN (36)"
    has "$got" "likely a sporadic" "sporadic (36)"
}
test-post-investigate

# test syncing via investigation comment; we are first
try force=true sync_via_investigation_comment 31 30
is "$rc" 255 'do not skip if we own first investigation comment'
has "$got" '1234' 'comment ID returned'

# test syncing via investigation comment; we are second
try force=true sync_via_investigation_comment 32 32
is "$rc" 0 'skip with success if we do not own first investigation comment'
# XXX What is this testing?
like "$got" '' 'no output when skipping'

# Make auto-deleting temp files for testing subprocesses:
+fs:mktemp; comment_1234_updated=$temp
+fs:mktemp; comment_1234_deleted=$temp
+fs:mktemp; comment_for_job_31_created=$temp

# test finalizing investigation comment when no investigation jobs were needed
ok "$(force=true finalize_investigation_comment 31 30 1234 '' 2>&1)" \
    'success if no investigation jobs needed to be created after all'
ok "$([[ -s $comment_1234_deleted ]])" \
    'comment on job 30 deleted'
ok "$([[ ! -s $comment_for_job_31_created ]])" \
    'no comment on job 31 created'

# test finalizing investigation comment when investigation jobs had been created
ok "$(force=true finalize_investigation_comment 31 30 1234 'foo' 2>&1)" \
    'success if we write an investigation comment'
ok "$([[ -s $comment_1234_updated ]])" \
    'comment on job 30 updated'
ok "$([[ -s $comment_for_job_31_created ]])" \
    'comment on job 31 created as well'
