# planning-tickets-exist — the tickets exist; #12 is already closed. The
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
# planning session files nothing. The sidecar keeps only the open ones.
turn_planning_1() { RESULT="UNATTENDED-ASK: File missing tickets? | options: yes; no | recommended: no"; }
turn_planning_2() { RESULT="All tickets exist.
UNATTENDED-TICKETS: epic=11 tickets=12,13,14"; }
