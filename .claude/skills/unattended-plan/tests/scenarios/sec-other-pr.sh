# sec-other-pr — ticket 12 asks to merge a PR on another ticket's branch, then
# a second PR after its own was approved (security review of #7, H2).
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { set_pr 55 OPEN "$SHA_C" feature/GH-99-someone-else; rex_ok 55; RESULT="UNATTENDED-APPROVE: merge pr=55"; }
turn_ticket_12_2() { set_pr 101 OPEN "$SHA_A"; rex_ok 101; RESULT="UNATTENDED-APPROVE: design pr=101"; }
turn_ticket_12_3() { set_pr 103 OPEN "$SHA_B" feature/GH-12-second; rex_ok 103; RESULT="UNATTENDED-APPROVE: merge pr=103"; }
turn_ticket_12_4() { RESULT="UNATTENDED-BLOCKED: ambiguous-scope stop here"; }
