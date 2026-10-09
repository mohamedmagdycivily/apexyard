# rt-hang-signal — a turn that keeps running while the supervisor is stopped
# by a signal. The child must not outlive the supervisor (review of #14).
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, TOOL_TEXT,
# ERR_TEXT and HANG.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { HANG=60; RESULT="UNATTENDED-ASK: Go? | options: yes; no | recommended: yes"; }
