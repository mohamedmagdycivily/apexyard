# stale-rex — a commit lands after Rex approved. The supervisor refuses to
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
# send /approve-merge and asks for a re-review.
turn_ticket_12_1() { set_pr 101 OPEN "$SHA_A"; rex_ok 101; set_pr 101 OPEN "$SHA_C"
  RESULT="UNATTENDED-APPROVE: merge pr=101"; }
turn_ticket_12_2() { rex_ok 101; RESULT="Re-reviewed.
UNATTENDED-APPROVE: merge pr=101"; }
turn_ticket_12_3() { set_pr 101 MERGED "$SHA_C"; set_issue 12 CLOSED; RESULT="UNATTENDED-NEXT: ticket=12 done pr=101"; }
