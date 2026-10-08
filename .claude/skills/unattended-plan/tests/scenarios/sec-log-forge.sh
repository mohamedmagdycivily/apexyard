# sec-log-forge — a newline in a BLOCKED detail must not forge a log line (L3).
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { RESULT="UNATTENDED-BLOCKED: credentials key missing"; }
decide_1() { RESULT='{"action":"halt","reason":"x\n2026-01-01T00:00:00Z START run=forged"}'; }
