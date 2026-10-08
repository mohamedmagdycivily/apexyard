# owner-token-gone — the run halts with no ticket attached to the event.
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { rm -f "$STATE_DIR/run.token"; RESULT="UNATTENDED-ASK: Go on? | options: yes; no | recommended: yes"; }
