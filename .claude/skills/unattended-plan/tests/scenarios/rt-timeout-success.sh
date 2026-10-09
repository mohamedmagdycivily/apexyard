# rt-timeout-success — the child writes a success result, then outlives the
# turn timeout. The result wins over the timeout (#13).
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, TOOL_TEXT,
# ERR_TEXT and HANG.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { set_pr 101 OPEN "$SHA_A"; rex_ok 101; HANG=30; RESULT="UNATTENDED-APPROVE: merge pr=101"; }
turn_ticket_12_2() { set_pr 101 MERGED "$SHA_A"; set_issue 12 CLOSED; RESULT="UNATTENDED-NEXT: ticket=12 done pr=101"; }
