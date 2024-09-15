#!/usr/bin/env bash

source test/init
bpan:source bashplus +err +fs +sym

plan tests 15

source openqa-label-known-issues
client_args=(api --host "$host_url")

export KEEP_REPORT_FILE=1
export KEEP_JOB_HTML_FILE=1

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
    if [ -p /dev/stdin ]; then
	in="$(cat)"
	if echo "$in" | grep -q "incomplete"; then
	    echo "$in" | awk -F'title="' '{split($2, a, "\""); print a[1]}'
	    return 0
	fi
	cat -
    fi
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

setup() {
  local id=$1
  declare -g id=$id
  declare -g testurl="https://openqa.opensuse.org/tests/${id}"
  declare -g tmplog=$(mktemp)
  declare -g out=$tmplog
  declare -g tmpjobpage=$(mktemp)
}

# test data with reason but 404 in curl respond
setup 404
older40d_date=$(date -uIs -d '-40days')
echo -n "Result:<b>incomplete</b>finished<abbr class=\"timeago\" title=\"${older40d_date}\"</abbr>>" > $tmpjobpage
export JOB_HTML_FILE=$tmpjobpage
try-client-output investigate_issue $id
is "$rc" 0 'investigate_issue with missing autoinst-log and with reason in job_data' #ok 3
has "$got" "without autoinst-log.txt older than 14 days. Do not label" "exits succefully when is old job without autoinst-log.txt"

# all assets are missing
setup 101
# `older1d_date` is used on the following 4 test cases
older1d_date=$(date -uIs -d '-1days')
sed -i "s/yyyy-mm-dd/${older1d_date}/" "$dir/data/${id}.json"
echo -n "Result:<b>incomplete</b>finished<abbr class=\"timeago\" title=\"${older1d_date}\"</abbr>>" > $tmpjobpage
html_out=$tmpjobpage
export JOB_HTML_FILE=$tmpjobpage
echo > $tmplog
out=$tmplog
try-client-output investigate_issue $id
is "$rc" 0 'investigate_issue with missing autoinst-log but with reason in job_data' # ok 4
has "$got" "does not have autoinst-log.txt or reason, cannot label" "investigation exits when no reason and autoinst-log"
# Cleanup 404.json
sed -i "s/${older1d_date}/yyyy-mm-dd/" "$dir/data/${id}.json"

# Unknown reason - not included in issues
setup 102
echo -n "\nthe reason is whatever" >> $tmplog
out=$tmplog
try-client-output investigate_issue $id
is "$rc" 0 'investigate no old issue with missing autoinst-log and unknown reason in job_data'
has "$got" "Unknown test issue, to be reviewed" "investigation still label Unknown reason"

setup 414
try-client-output investigate_issue $id
is "$rc" 0 'investigate_issue with missing old autoinst-log and without reason in job_data'
has "$got" "does not have autoinst-log.txt or reason, cannot label" "investigation exits successfully when no reason and no autoinst-log"

setup 200
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
