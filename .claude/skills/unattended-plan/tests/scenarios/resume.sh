# resume — used by test_state_resume.sh. Ticket 12 resumes its session; 13 is fresh.
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { set_pr 101 MERGED "$SHA_A"; set_issue 12 CLOSED; RESULT="UNATTENDED-NEXT: ticket=12 done pr=101"; }
turn_ticket_13_1() { set_pr 102 OPEN "$SHA_B"; rex_ok 102; RESULT="UNATTENDED-APPROVE: merge pr=102"; }
turn_ticket_13_2() { set_pr 102 MERGED "$SHA_B"; set_issue 13 CLOSED; RESULT="UNATTENDED-NEXT: ticket=13 done pr=102"; }
