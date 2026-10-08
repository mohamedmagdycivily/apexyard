# ci-red — CI is red at approval time twice: halt.
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { set_pr 101 OPEN "$SHA_A"; rex_ok 101; ci 101 fail; RESULT="UNATTENDED-APPROVE: merge pr=101"; }
turn_ticket_12_2() { set_pr 101 OPEN "$SHA_B"; rex_ok 101; RESULT="Pushed a fix.
UNATTENDED-APPROVE: merge pr=101"; }
