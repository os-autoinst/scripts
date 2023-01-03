#!/usr/bin/env bash

source test/init

plan tests 27

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
    elif [[ $@ == "-X POST jobs/30/comments text=Starting investigation for job 31" ]]; then
        echo '{"id": 1234}'
    elif [[ $@ == $'-X PUT jobs/30/comments/1234 text=Automatic investigation jobs for job 31:\n\nfoo' ]]; then
        touch comment_1234_updated
    elif [[ $@ == '-X DELETE jobs/30/comments/1234' ]]; then
        touch comment_1234_deleted
    elif [[ $@ == $'-X POST jobs/31/comments text=Automatic investigation jobs for job 31:\n\nfoo' ]]; then
        touch comment_for_job_31_created
    elif [[ $@ == "-X GET jobs/30/comments" ]]; then
        echo '[{"id": 1234, "text":"Starting investigation for 31"},{"id": 1235, "text":"unrelated comment"}]'
    elif [[ $@ == "-X POST jobs/32/comments text=Starting investigation for job 32" ]]; then
        echo '{"id": 1237}'
    elif [[ $@ == "-X GET jobs/32/comments" ]]; then
        echo '[{"id": 1236, "text":"Starting investigation for job 32"},{"id": 1237, "text":"Starting investigation for job 32"}]'
    elif [[ $@ == '--apibase  --json tests/27/dependencies_ajax' ]]; then
        echo '{"cluster":{}, "edges":[], "nodes":[{"id":27,"state":"done","result":"passed"}]}'
    elif [[ $@ == '--apibase  --json tests/28/dependencies_ajax' ]]; then
        echo '{"cluster":{}, "edges":[], "nodes":[{"id":28,"state":"done","result":"failed"}]}'
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

rc=0
clone_call=echo
out=$(clone 23 24 2>&1 ) || rc=$?
is "$rc" 0 "Successful clone"
testlabel="vim:investigate"
is "$out" "* **$testlabel**: " "Expected markdown output of job urls for unsupported clusters"

rc=0
out=$(investigate 27 2>&1) || rc=$?
is "$rc" 0 'success regardless of actually triggered jobs'
is "$out" "Job 27 already has a clone, skipping investigation. Use the env variable 'force=true' to trigger investigation jobs"

rc=0
out=$(force=true investigate 28 2>&1) || rc=$?
is "$rc" 0 'still success when job is skipped (because of exclude_no_group)'
like "$out" "exclude_no_group is set, skipping investigation"

rc=0
out=$(investigate 30 2>&1) || rc=$?
is "$rc" 142 'investigation postponed because other job in cluster is not done'
is "$out" "Postponing to investigate job 30: waiting until 1 pending parallel job(s) finished"

rc=0
out=$(echo 30 | main 2>&1) || rc=$?
is "$rc" 142 'return code (for postponing) passed by main function'
is "$out" "Postponing to investigate job 30: waiting until 1 pending parallel job(s) finished" 'output passed by main function'

rc=0
out=$(investigate 32 2>&1) || rc=$?
is "$rc" 0 'investigation not postponed if other job in dependency tree not done but cluster itself is done'

rc=0
out=$(force=true investigate 31 2>&1) || rc=$?
is "$rc" 0 'success when job is skipped (because of exclude_no_group and job w/o group)'
like "$out" 'Job w/o job group, \$exclude_no_group is set, skipping investigation'

# test syncing via investigation comment; we're first
rc=0
out=$(force=true sync_via_investigation_comment 31 30 2>&1) || rc=$?
is "$rc" 255 'do not skip if we own first investigation comment'
like "$out" '1234' 'comment ID returned'

# test syncing via investigation comment; we're second
rc=0
out=$(force=true sync_via_investigation_comment 32 32 2>&1) || rc=$?
is "$rc" 0 'skip with success if we do not own first investigation comment'
like "$out" '' 'no output when skipping'

# delete certain files used to trace whether API calls happened
for trace_file in comment_1234_updated comment_for_job_31_created comment_1234_deleted; do
    [[ -f $trace_file ]] && unlink "$trace_file"
done

# test finalizing investigation comment when no investigation jobs were needed
rc=0
out=$(force=true finalize_investigation_comment 31 30 1234 '' 2>&1) || rc=$?
is "$rc" 0 'success if no investigation jobs needed to be created after all'
[[ -f comment_1234_deleted ]] && comment_1234_deleted=1 || comment_1234_deleted=0
[[ -f comment_for_job_31_created ]] && comment_for_job_31_created=1 || comment_for_job_31_created=0
is "$comment_1234_deleted" 1 'comment on job 30 deleted'
is "$comment_for_job_31_created" 0 'no comment on job 31 created'

# test finalizing investigation comment when investigation jobs had been created
rc=0
out=$(force=true finalize_investigation_comment 31 30 1234 'foo' 2>&1) || rc=$?
is "$rc" 0 'success if we write an investigation comment'
[[ -f comment_1234_updated ]] && comment_1234_updated=1 || comment_1234_updated=0
[[ -f comment_for_job_31_created ]] && comment_for_job_31_created=1 || comment_for_job_31_created=0
is "$comment_1234_updated" 1 'comment on job 30 updated'
is "$comment_for_job_31_created" 1 'comment on job 31 created as well'
