# planning-bad-number — the planning session names a ticket that does not exist.
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_planning_1() { RESULT="UNATTENDED-TICKETS: epic=11 tickets=12,99"; }
turn_planning_2() { RESULT="UNATTENDED-TICKETS: epic=11 tickets=12"; }
