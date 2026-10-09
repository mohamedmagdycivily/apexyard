# rt-cost-delta — three turns of one session cost 5, 1 and 1: the CLI reports
# the running total 5, 6, 7. The ticket costs 7, not 18 (#13).
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, TOOL_TEXT,
# ERR_TEXT and HANG.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { COST=5; set_pr 101 OPEN "$SHA_A"; rex_ok 101; RESULT="UNATTENDED-ASK: Go? | options: yes; no | recommended: yes"; }
turn_ticket_12_2() { COST=1; RESULT="UNATTENDED-APPROVE: merge pr=101"; }
turn_ticket_12_3() { COST=1; set_pr 101 MERGED "$SHA_A"; set_issue 12 CLOSED; RESULT="UNATTENDED-NEXT: ticket=12 done pr=101"; }
