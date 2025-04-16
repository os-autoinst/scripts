#!/usr/bin/env bash

source test/init
bpan:source bashplus +err +fs +sym

plan tests 6

submit_target_extra="openSUSE:Backports:SLE-15-SP7:Update"

osc_dists_output='
openSUSE Backports for SLE 15 SP6 openSUSE:Backports:SLE-15-SP6 15.6 standard
openSUSE Backports for SLE 15 SP5 openSUSE:Backports:SLE-15-SP5 15.5 standard
openSUSE Backports for SLE 15 SP6:Update  openSUSE:Backports:SLE-15-SP6:Update:GA 1.0 standard 
openSUSE Backports for SLE 15 SP4 openSUSE:Backports:SLE-15-SP4 15.4 standard'

check_submit_target_extra_expansion() {
    update_prj="${submit_target_extra##*:}"
    current_prj="${submit_target_extra%:*}"
    current_prj="${current_prj%:*}"
    latest_submit_target_extra_version=$(echo "$osc_dists_output" | grep "$current_prj" | awk -v prj="$current_prj" '{for (i=1; i<=NF; i++) if ($i ~ "^" prj ":") print $i}' | sort --version-sort | tail -n 1)
    submit_target_extra="$latest_submit_target_extra_version:$update_prj"
    [[ -z $latest_submit_target_extra_version ]] && echo "Project not found." && return 1
    echo "$submit_target_extra"
}

try check_submit_target_extra_expansion
is "$rc" 0 "rc should be 0"
is "$got" "openSUSE:Backports:SLE-15-SP6:Update" "the latest version is used from the osc dists output"

osc_dists_output=''
try check_submit_target_extra_expansion
is "$rc" 1 "rc should be 1"
is "$got" "Project not found." "Error if project no match any from osc dists output"

osc_dists_output='
openSUSE Backports for SLE 15 SP6 openSUSE:Backports:SLE-15-SP6 15.6 standard
openSUSE Backports for SLE 15 SP7 openSUSE:Backports:SLE-17-SP5 17.5 standard
openSUSE Backports for SLE 15 SP6:Update  openSUSE:Backports:SLE-15-SP6:Update:GA 1.0 standard
openSUSE Backports for SLE 15 SP4 openSUSE:Backports:SLE-15-SP4 15.4 standard'

try check_submit_target_extra_expansion
is "$rc" 0 "rc should be 0"
is "$got" "openSUSE:Backports:SLE-17-SP5:Update" "the latest version is used from the osc dists output comparing the major version"
