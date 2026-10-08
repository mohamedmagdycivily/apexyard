# token-removed — the run token disappears before the approval.
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { set_pr 101 OPEN "$SHA_A"; rex_ok 101; rm -f "$STATE_DIR/run.token"
  RESULT="UNATTENDED-APPROVE: merge pr=101"; }
