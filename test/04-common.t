#!/usr/bin/env bash

source test/init

plan tests 12

source _common

success() {
    echo "SUCCESS $@"
}

failure() {
    warn "oh noe!"
    return 23
}

rc=0
output=$(runcli success a b c 2>&1) || rc=$?
is $rc 0 "runcli success"
is "$output" "SUCCESS a b c" "runcli successful output"

output=$(runcli failure a b c 2>&1) || rc=$?
is $rc 23 "runcli failure"
like "$output", "test/04-common.t.*failure a b c.*oh noe" "runcli failure output"

tw_openqa_host=foo
get_image() {
    echo "opensuse-Tumbleweed-i386-20380101-Tumbleweed@32bit-3G.qcow2"
}
latest_published_tw_builds() {
    echo "20380101 20390101"
}

rc=0
output=$(find_latest_published_tumbleweed_image "23" "i386" "32bit" qcow)
is $rc 0 "find_latest_published_tumbleweed_image success (qcow)"
image=opensuse-Tumbleweed-i386-20380101-Tumbleweed@32bit-3G.qcow2
is "$output" "$image" "Found expected image (qcow)"

rc=0
output=$(find_latest_published_tumbleweed_image "23" "i386" "32bit" iso)
is $rc 0 "find_latest_published_tumbleweed_image success (iso)"
image=opensuse-Tumbleweed-i386-20380101-Tumbleweed@32bit-3G.qcow2
is "$output" "$image" "Found expected image (iso)"

get_image() {
    echo "null"
}
rc=0
output=$(find_latest_published_tumbleweed_image "23" "i386" "32bit" qcow 2>&1) || rc=$?
is "$rc" 2 "find_latest_published_tumbleweed_image failure (qcow)"
like "$output" "Unable to determine qcow image" "Expected error message (qcow)"

latest_published_tw_builds() {
    echo ""
}
rc=0
output=$(find_latest_published_tumbleweed_image "23" "i386" "32bit" qcow 2>&1) || rc=$?
is "$rc" 1 "find_latest_published_tumbleweed_image failure (no builds)"
like "$output" "Unable to find latest published Tumbleweed builds" "Expected error message (no builds)"
