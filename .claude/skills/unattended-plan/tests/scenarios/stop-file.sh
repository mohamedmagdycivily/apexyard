# stop-file — the owner runs --stop during the first turn.
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { : > "$STATE_DIR/stop"; rm -f "$STATE_DIR/run.token"
  RESULT="UNATTENDED-ASK: Continue? | options: yes; no | recommended: yes"; }
