# not-last-line — the protocol line is followed by more text: nudge once.
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { set_pr 101 OPEN "$SHA_A"; rex_ok 101
  RESULT="UNATTENDED-APPROVE: merge pr=101
Let me know."; }
turn_ticket_12_2() { RESULT="UNATTENDED-APPROVE: merge pr=101"; }
turn_ticket_12_3() { set_pr 101 MERGED "$SHA_A"; set_issue 12 CLOSED; RESULT="UNATTENDED-NEXT: ticket=12 done pr=101"; }
