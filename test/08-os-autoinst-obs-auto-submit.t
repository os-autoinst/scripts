#!/usr/bin/env bash

source test/init
bpan:source bashplus +err +fs +sym

plan tests 6

submit_target_extra_project="openSUSE:Backports"
osc_dists_output='
openSUSE Backports for SLE 15 SP6 openSUSE:Backports:SLE-15-SP6 15.6 standard
openSUSE Backports for SLE 15 SP5 openSUSE:Backports:SLE-15-SP5 15.5 standard
openSUSE Backports for SLE 15 SP6:Update  openSUSE:Backports:SLE-15-SP6:Update:GA 1.0 standard 
openSUSE Backports for SLE 15 SP4 openSUSE:Backports:SLE-15-SP4 15.4 standard'

osc() {
    if [[ "$1" == "dists" ]]; then
        echo "$osc_dists_output"
        return 0
    else
        echo "Not mocked 'osc' call:" "$@" >&2
        return 1
    fi
}
source os-autoinst-obs-auto-submit

try get_submit_target_extra_latest_version
is "$rc" 0 "rc should be 0"
is "$got" "openSUSE:Backports:SLE-15-SP6:Update" "the latest version is used from the osc dists output"

osc_dists_output=''
try get_submit_target_extra_latest_version
is "$rc" 1 "rc should be 1"
is "$got" "Project not found." "Error if project no match any from osc dists output"

osc_dists_output='
openSUSE Backports for SLE 15 SP6 openSUSE:Backports:SLE-15-SP6 15.6 standard
openSUSE Backports for SLE 15 SP7 openSUSE:Backports:SLE-17-SP5 17.5 standard
openSUSE Backports for SLE 15 SP6:Update  openSUSE:Backports:SLE-15-SP6:Update:GA 1.0 standard
openSUSE Backports for SLE 15 SP4 openSUSE:Backports:SLE-15-SP4 15.4 standard'

try get_submit_target_extra_latest_version
is "$rc" 0 "rc should be 0"
is "$got" "openSUSE:Backports:SLE-17-SP5:Update" "the latest version is used from the osc dists output comparing the major version"
