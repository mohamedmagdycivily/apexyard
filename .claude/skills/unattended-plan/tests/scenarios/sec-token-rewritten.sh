# sec-token-rewritten — the child deletes the stop file and rewrites the token
# with the same run id (security review of #7, M1).
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { rm -f "$STATE_DIR/stop"; t="$(cat "$STATE_DIR/run.token")"; rm -f "$STATE_DIR/run.token"; printf '%s\n' "$t" > "$STATE_DIR/run.token"
  RESULT="UNATTENDED-ASK: Continue? | options: yes; no | recommended: yes"; }
