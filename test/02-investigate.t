#!/usr/bin/env bash

source test/init
bpan:source bashplus +err +fs +sym

plan tests 69

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
    # GET jobs/id
    if [[ "$1 $2" == "--json jobs/10024" ]]; then
        echo '{"job": { "test": "vim", "priority": 50, "settings" : {} } }'
    elif [[ "$1 $2" == "--json jobs/10027" ]]; then
        echo '{"job": { "test": "vim", "clone_id" : 10028 } }'
    elif [[ "$1 $2" == "--json jobs/3000" ]]; then
        echo '{"job": { "test": "vim", "result": "failed" } }'
    elif [[ "$1 $2" == "--json jobs/3001" ]]; then
        echo '{"job": { "test": "vim:investigate:last_good_tests", "result": "failed" } }'
    elif [[ "$1 $2" == "--json jobs/3002" ]]; then
        echo '{"job": { "test": "vim", "result": "failed" } }'
    elif [[ "$1 $2" == "--json jobs/3003" ]]; then
        echo '{"job": { "test": "vim", "result": "failed" } }'
    elif [[ "$1 $2" == "--json jobs/30001" ]]; then
        echo '{"job": { "test": "vim:investigate:retry", "result": "failed", "settings": {"OPENQA_INVESTIGATE_ORIGIN": "3000"} } }'
    elif [[ "$1 $2" == "--json jobs/30002" ]]; then
        echo '{"job": { "test": "vim:investigate:retry", "result": "passed", "settings": {"OPENQA_INVESTIGATE_ORIGIN": "3000"} } }'
    elif [[ "$1 $2" == "--json jobs/30003" ]]; then
        echo '{"job": { "test": "vim:investigate:retry", "result": "softfailed", "settings": {"OPENQA_INVESTIGATE_ORIGIN": "3000"} } }'
    elif [[ "$1 $2" == "--json jobs/30004" ]]; then
        echo '{"job": { "test": "vim:investigate:retry", "result": "softfailed", "settings": {"OPENQA_INVESTIGATE_ORIGIN": "3000"} } }'
    elif [[ "$1 $2" == "--json jobs/30005" ]]; then
        echo '{"job": { "test": "vim-other:investigate:retry", "result": "failed", "settings": {"OPENQA_INVESTIGATE_ORIGIN": "3000"} } }'
    elif [[ "$1 $2" =~ --json.jobs/3003[134] ]]; then
        echo '{"job": { "test": "vim:investigate:retry", "result": "failed", "settings": {"OPENQA_INVESTIGATE_ORIGIN": "3003"} } }'
    elif [[ "$1 $2" == "--json jobs/30032" ]]; then
        echo '{"job": { "test": "vim:investigate:retry", "result": "passed", "settings": {"OPENQA_INVESTIGATE_ORIGIN": "3003"} } }'

    # GET experimental/jobs/id/status
    elif [[ "$2" =~ experimental/jobs/(30001|30002)/status ]]; then
        echo '{ "state": "done", "test": "vim:investigate:retry", "result": "failed" }'
    elif [[ "$2" =~ experimental/jobs/(30003|30004)/status ]]; then
        echo '{ "state": "done", "test": "vim:investigate:retry", "result": "passed" }'
    elif [[ "$2" =~ experimental/jobs/(30021|30022)/status ]]; then
        echo '{ "state": "done", "test": "vim:investigate:retry", "result": "failed" }'
    elif [[ "$2" =~ experimental/jobs/(30023|30024)/status ]]; then
        echo '{ "state": "running", "test": "vim:investigate:retry", "result": "none" }'
    elif [[ "$2" =~ experimental/jobs/(30031|30033)/status ]]; then
        echo '{ "state": "done", "test": "vim:investigate:retry", "result": "failed" }'
    elif [[ "$2" =~ experimental/jobs/(30032|30034)/status ]]; then
        echo '{ "state": "done", "test": "vim:investigate:retry", "result": "passed" }'

    # POST jobs/id/comments
    elif [[ $@ == "-X POST jobs/10030/comments text=Starting investigation for job 10031" ]]; then
        echo '{"id": 1234}'
    elif [[ $@ =~ $'-X POST jobs/10031/comments text=Automatic investigation jobs for job 10031:\n\nfoo' ]]; then
        echo true > "$comment_for_job_31_created"
    elif [[ $@ == "-X POST jobs/10032/comments text=Starting investigation for job 10032" ]]; then
        echo '{"id": 1237}'
    elif [[ $@ =~ "-X POST jobs/3000/comments" ]]; then
        warn "Commenting 3000 ($@)"
        exit 99
    elif [[ $@ =~ "-X POST jobs/30002/comments" ]]; then
        warn "Commenting 30002 ($@)"
        exit 99
    elif [[ $@ =~ "-X POST jobs/3003/comments" ]]; then
        warn "Commenting 3003 ($@)"
        exit 99

    # GET jobs/id/comments
    elif [[ $@ == "-X GET jobs/10030/comments" ]]; then
        echo '[{"id": 1234, "text":"Starting investigation for 10031"},{"id": 1235, "text":"unrelated comment"}]'
    elif [[ $@ == "-X GET jobs/10032/comments" ]]; then
        echo '[{"id": 1236, "text":"Starting investigation for job 10032"},{"id": 1237, "text":"Starting investigation for job 10032"}]'
    elif [[ $@ == "-X GET jobs/3000/comments" ]]; then
        echo '[{"id": 1236, "text":"Automatic investigation jobs for job\n**a:investigate:retry**:url/t30001\n**a:investigate:last_good_tests:coffee**:url/t30002\n**a:investigate:last_good_build:2001**:url/t30003\n**a:investigate:last_good_tests_and_build:coffee+2001**:url/t30004"}]'
    elif [[ $@ == "-X GET jobs/3002/comments" ]]; then
        echo '[{"id": 1236, "text":"Automatic investigation jobs for job\n**a:investigate:retry**:url/t30021\n**a:investigate:last_good_tests:coffee**:url/t30022\n**a:investigate:last_good_build:2001**:url/t30023\n**a:investigate:last_good_tests_and_build:coffee+2001**:url/t34024"}]'
    elif [[ $@ == "-X GET jobs/3003/comments" ]]; then
        echo '[{"id": 1236, "text":"Automatic investigation jobs for job\n**a:investigate:retry**:url/t30031\n**a:investigate:last_good_tests:coffee**:url/t30032\n**a:investigate:last_good_build:2001**:url/t30033\n**a:investigate:last_good_tests_and_build:coffee+2001**:url/t30034"}]'

    # PUT jobs/id/comments/id
    elif [[ $@ =~ $'-X PUT jobs/10030/comments/1234 text=Automatic investigation jobs for job 10031:\n\nfoo' ]]; then
        echo true > "$comment_1234_updated"

    # DELETE jobs/id/comments/id
    elif [[ $@ == '-X DELETE jobs/10030/comments/1234' ]]; then
        echo true > "$comment_1234_deleted"

    # GET tests/id/dependencies_ajax
    elif [[ $@ == '--apibase  --json tests/10027/dependencies_ajax' ]]; then
        echo '{"cluster":{}, "edges":[], "nodes":[{"id":10027,"state":"done","result":"passed"}]}'
    elif [[ $@ == '--apibase  --json tests/10028/dependencies_ajax' ]]; then
        echo '{"cluster":{}, "edges":[], "nodes":[{"id":10028,"state":"done","result":"failed"}]}'
    elif [[ $@ == '--apibase  --json tests/10030/dependencies_ajax' ]]; then
        echo '{"cluster":{"cluster_foo":[10028,10030],"cluster_bar":[29]}, "edges":[], "nodes":[{"id":10028,"state":"uploading","result":"none"},{"id":10030,"state":"done","result":"passed"}]}'
    elif [[ $@ == '--apibase  --json tests/10032/dependencies_ajax' ]]; then
        echo '{"cluster":{"cluster_foo":[10028,10032],"cluster_bar":[29]}, "edges":[], "nodes":[{"id":10028,"state":"cancelled","result":"none"},{"id":10032,"state":"done","result":"failed"},{"id":29,"state":"running","result":"running"}]}'
    elif [[ $@ == '--apibase  --json tests/10031/dependencies_ajax' ]]; then
        # job with cancelled job in the cluster (should be treated like a done job)
        echo '{"cluster":{"cluster_foo":[10028,10031],"cluster_bar":[29]}, "edges":[], "nodes":[{"id":10028,"state":"cancelled","result":"none"},{"id":10031,"state":"done","result":"failed"}]}'

    # fallback
    else
        args="$@"
        echo '{"debug": "openqa-li '"${args//$'\n'/ }"'"}'
    fi
}

clone_call=echo
_clone_call() {
    echo "$@" >&2
}
clone_call=_clone_call
try clone 10023 10024
is "$rc" 0 "Successful clone"
testlabel="vim:investigate"
has "$got" "* **$testlabel**: " "Expected markdown output of job urls for unsupported clusters"
has "$got" '_TRIGGER_JOB_DONE_HOOK=1' "job is cloned with _TRIGGER_JOB_DONE_HOOK"

clone_call=echo
try investigate 10027
is "$rc" 0 'success regardless of actually triggered jobs'
is "$got" "Job 10027 already has a clone, skipping investigation. Use the env variable 'force=true' to trigger investigation jobs"

try force=true investigate 10028
is "$rc" 0 'still success when job is skipped (because of exclude_no_group)'
has "$got" "exclude_no_group is set, skipping investigation"

try investigate 10030
is "$rc" 142 'investigation postponed because other job in cluster is not done'
is "$got" "Postponing to investigate job 10030: waiting until 1 pending parallel job(s) finished"

try main 10030
is "$rc" 142 'return code (for postponing) passed by main function'
is "$got" "Postponing to investigate job 10030: waiting until 1 pending parallel job(s) finished" 'output passed by main function'

try investigate 10032
is "$rc" 0 'investigation not postponed if other job in dependency tree not done but cluster itself is done'

try force=true investigate 10031
is "$rc" 0 'success when job is skipped (because of exclude_no_group and job w/o group)'
has "$got" 'Job w/o job group, $exclude_no_group is set, skipping investigation'

test-post-investigate() {
    # job is one of the other investigation types, e.g. :investigate:last_good_tests
    try investigate 3001
    is "$rc" 0 'success (3001)'
    has "$got" "Job is ':investigate:' already, skipping investigation" "skip investigation, not a retry (3001)"

    # retry failed
    # product issue
    try investigate 30001
    is "$rc" 2 'mocked function returned failure (30001)'
    has "$got" "Commenting 3000" "Posting comment on OPENQA_INVESTIGATE_ORIGIN (30001)"
    has "$got" "Investigate retry job **vim:investigate:retry**" "retry test name appears in comment(30001)"
    has "$got" "likely a product issue" "product issue (30001)"

    # retry passed
    try investigate 30003
    is "$rc" 2 'mocked function returned failure (30003)'
    has "$got" "Commenting 3000" "Posting comment on OPENQA_INVESTIGATE_ORIGIN (30003)"
    has "$got" "likely a sporadic" "sporadic (passed) (30003)"

    # retry softfailed
    try investigate 30003
    is "$rc" 2 'mocked function returned failure (30003)'
    has "$got" "Commenting 3000" "Posting comment on OPENQA_INVESTIGATE_ORIGIN (30003)"
    has "$got" "likely a sporadic" "sporadic (softfailed) (30003)"

    # retry softfailed
    try investigate 30005
    is "$rc" 0 'early return (other test in cluster) (30005)'
    has "$got" "is not a retry" "vim-other vs. vim (30005)"

    # test issue
    try investigate 30031
    is "$rc" 2 'mocked function returned failure (30031)'
    has "$got" "Commenting 3003" "Posting comment on OPENQA_INVESTIGATE_ORIGIN (30031)"
    has "$got" "Investigate retry job **vim:investigate:retry**" "retry test name appears in comment(30031)"
    has "$got" "likely a test issue" "test issue (30031)"

    # 142 not finished yet
    local job_data='{"job": { "result": "failed", "settings": { "OPENQA_INVESTIGATE_ORIGIN": "https://localhost/t3002" } } }'
    try post-investigate 2039 "vim:investigate:retry"
    is "$rc" 142 'post-investigate returned 142 (not all jobs finished yet) (2039)'

    # various combinations of investigation results
    t1="fail"

    t2="passed" t3="passed" t4="passed"
    fetch-investigation-results() {
        echo "retry|1|$t1
last_good_tests|2|$t2
last_good_build|3|$t3
last_good_tests_and_build|4|$t4"
    }
    product_issue=false
    test_issue=false
    identify-issue-type 999
    is "$product_issue" "false" "$t1+$t2+$t3+$t4 -> false"
    is "$test_issue" "false" "$t1+$t2+$t3+$t4 -> false"

    t2="fail" t3="passed" t4="passed"
    identify-issue-type 999
    is "$product_issue" "true" "$t1+$t2+$t3+$t4 -> true"
    is "$test_issue" "false" "$t1+$t2+$t3+$t4 -> false"

    t2="fail" t3="fail" t4="passed"
    identify-issue-type 999
    is "$product_issue" "false" "$t1+$t2+$t3+$t4 -> false"
    is "$test_issue" "false" "$t1+$t2+$t3+$t4 -> false"

    t2="" t3="passed" t4="passed"
    identify-issue-type 999
    is "$product_issue" "true" "$t1+$t2+$t3+$t4 -> true"
    is "$test_issue" "false" "$t1+$t2+$t3+$t4 -> false"

    t2="" t3="passed" t4=""
    identify-issue-type 999
    is "$product_issue" "true" "$t1+$t2+$t3+$t4 -> true"
    is "$test_issue" "false" "$t1+$t2+$t3+$t4 -> false"

    t2="fail" t3="" t4="fail"
    identify-issue-type 999
    is "$product_issue" "false" "$t1+$t2+$t3+$t4 -> false"
    is "$test_issue" "false" "$t1+$t2+$t3+$t4 -> false"

    t2="passed" t3="" t4=""
    identify-issue-type 999
    is "$product_issue" "false" "$t1+$t2+$t3+$t4 -> false"
    is "$test_issue" "true" "$t1+$t2+$t3+$t4 -> true"

    t2="passed" t3="passed" t4=""
    identify-issue-type 999
    is "$product_issue" "false" "$t1+$t2+$t3+$t4 -> false"
    is "$test_issue" "false" "$t1+$t2+$t3+$t4 -> false"

    t2="passed" t3="" t4="passed"
    identify-issue-type 999
    is "$product_issue" "false" "$t1+$t2+$t3+$t4 -> false"
    is "$test_issue" "true" "$t1+$t2+$t3+$t4 -> true"

    t2="passed" t3="failed" t4="passed"
    identify-issue-type 999
    is "$product_issue" "false" "$t1+$t2+$t3+$t4 -> false"
    is "$test_issue" "true" "$t1+$t2+$t3+$t4 -> true"

    t2="passed" t3="failed" t4="failed"
    identify-issue-type 999
    is "$product_issue" "false" "$t1+$t2+$t3+$t4 -> false"
    is "$test_issue" "false" "$t1+$t2+$t3+$t4 -> false"
}

test-post-investigate

# test syncing via investigation comment; we are first
try force=true sync_via_investigation_comment 10031 10030
is "$rc" 255 'do not skip if we own first investigation comment'
has "$got" '1234' 'comment ID returned'

# test syncing via investigation comment; we are second
try force=true sync_via_investigation_comment 10032 10032
is "$rc" 0 'skip with success if we do not own first investigation comment'
# XXX What is this testing?
like "$got" '' 'no output when skipping'

# Make auto-deleting temp files for testing subprocesses:
+fs:mktemp; comment_1234_updated=$temp
+fs:mktemp; comment_1234_deleted=$temp
+fs:mktemp; comment_for_job_31_created=$temp

# test finalizing investigation comment when no investigation jobs were needed
ok "$(force=true finalize_investigation_comment 10031 10030 1234 '' 2>&1)" \
    'success if no investigation jobs needed to be created after all'
ok "$([[ -s $comment_1234_deleted ]])" \
    'comment on job 10030 deleted'
ok "$([[ ! -s $comment_for_job_31_created ]])" \
    'no comment on job 10031 created'

# test finalizing investigation comment when investigation jobs had been created
ok "$(force=true finalize_investigation_comment 10031 10030 1234 'foo' 2>&1)" \
    'success if we write an investigation comment'
ok "$([[ -s $comment_1234_updated ]])" \
    'comment on job 10030 updated'
ok "$([[ -s $comment_for_job_31_created ]])" \
    'comment on job 10031 created as well'
