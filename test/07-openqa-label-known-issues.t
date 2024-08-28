#!/usr/bin/env bash

source test/init
bpan:source bashplus +err +fs +sym

plan tests 15

source openqa-label-known-issues
client_args=(api --host "$host_url")

export KEEP_REPORT_FILE=1

client_output=''
mock-client-output() {
    client_output+="client_call $@"$'\n'
    echo "$client_output\n"
}

client_call=(mock-client-output "${client_call[@]}")
autoinst_log=$dir/data/04-autoinst.txt

try-client-output() {
    client_output=''
    try "$*"' && echo "$client_output"'
}
openqa-cli() {
    local id=$(basename "$4")
    cat "$dir/data/$id.json"
}
curl() {
    if [[ "$7" =~ /(404|414|101|102)/file/autoinst-log.txt ]]; then
        echo -n "404"
    else
        echo -n "200"
    fi
}
comment_on_job() {
    local id=$1 comment=$2 force_result=${3:-''}
    echo "$comment"
}
out=''
hxnormalize() {
    cat "$2"
}
hxselect() {
    cat -
}

try investigate_issue
is "$rc" 1 'id required'
# error in tap output is from here

issues="159876
[security] test fails in krb auto_review:\"com:/tmp/nfsdir /tmp/mntdir' failed\":force_result:softfailed
openqa-force-result
137420
[qe-sap] test fails in network_peering auto_review:\"az network vnet peering create.+failed\"
action
73375
Job incompletes with reason auto_review:\"(?m)api failure$\" (and no further details)
action"

# test data with reason but 404 in curl respond
id=404
testurl="https://openqa.opensuse.org/tests/${id}"
try-client-output investigate_issue $id
is "$rc" 0 'investigate_issue with missing autoinst-log and with reason in job_data'
has "$got" "without autoinst-log.txt older than 14 days. Do not label" "exits succefully when is old job without autoinst-log.txt"

# all assets are missing
id=101
testurl="https://openqa.opensuse.org/tests/${id}"
# `cur_date` is used on the following 4 test cases
cur_date=$(date +%F)
sed -i "s/yyyy-mm-dd/${cur_date}/" "$dir/data/${id}.json"
+fs:mktemp
tmplog=$temp
echo -n "Result: <b>incomplete</b>, finished <abbr class=\"timeago\" title=\"${cur_date}T08:06:42Z\"</abbr>>" > $tmplog
out=$tmplog
try-client-output investigate_issue $id
is "$rc" 0 'investigate_issue with missing autoinst-log but with reason in job_data'
has "$got" "does not have autoinst-log.txt or reason, cannot label" "investigation exits when no reason and autoinst-log"
# Cleanup 404.json
sed -i "s/${cur_date}/yyyy-mm-dd/" "$dir/data/${id}.json"

# Unknown reason - not included in issues
id=102
testurl="https://openqa.opensuse.org/tests/${id}"
echo -n "Result: <b>incomplete</b>, finished <abbr class=\"timeago\" title=\"${cur_date}T08:06:42Z\"</abbr>>" > $tmplog
echo -n "\nthe reason is whatever" >> $tmplog
out=$tmplog
try-client-output investigate_issue $id
is "$rc" 0 'investigate no old issue with missing autoinst-log and unknown reason in job_data'
has "$got" "Unknown test issue, to be reviewed" "investigation still label Unknown reason"

id=414
testurl="https://openqa.opensuse.org/tests/${id}"
try-client-output investigate_issue $id
is "$rc" 0 'investigate_issue with missing old autoinst-log and without reason in job_data'
has "$got" "does not have autoinst-log.txt or reason, cannot label" "investigation exits successfully when no reason and no autoinst-log"

id=200
testurl="https://openqa.opensuse.org/tests/${id}"
cp $autoinst_log $tmplog
out=$tmplog
try-client-output investigate_issue $id
is "$rc" 0 'investigate_issue with autoinst-log and without reason'
has "$got" "test fails in network_peering" "investigation label job with matched autoinst-log context"

# handle_unreview branch
echo > "$tmplog"
out=$tmplog
try-client-output investigate_issue $id
is "$rc" 0 'job with empty autoinst-log checks unknown issue'
has "$got" "Unknown test issue, to be reviewed" "investigation still label Unknown issue"

echo -n "[error] Failed to download" > $out
try-client-output investigate_issue $id
is "$rc" 0 'job label without tickets'
has "$got" "label:download_error potentially out-of-space worker?" "investistigation label correctly job without ticket"
