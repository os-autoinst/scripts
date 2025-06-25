#!/usr/bin/env bash
echo 1..1

color=always
source _common

log-warn "Demo warning"
log-info "Demo info" >&2
log-debug "Demo debug"

echo "ok 1"
