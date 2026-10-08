# sec-forged-marker — a Rex marker file with no posted Rex review is not
# enough for an approval (security review of #7, M2).
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { set_pr 101 OPEN "$SHA_A"; rex_marker_only 101; RESULT="UNATTENDED-APPROVE: merge pr=101"; }
turn_ticket_12_2() { rex_ok 101; RESULT="Reviewed.
UNATTENDED-APPROVE: merge pr=101"; }
turn_ticket_12_3() { set_pr 101 MERGED "$SHA_A"; set_issue 12 CLOSED; RESULT="UNATTENDED-NEXT: ticket=12 done pr=101"; }
