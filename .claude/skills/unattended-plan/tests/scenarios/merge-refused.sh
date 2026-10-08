# merge-refused — /approve-merge is sent but the PR never merges: three
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
# approve-then-refusal cycles halt the run.
turn_ticket_12_1() { set_pr 101 OPEN "$SHA_A"; rex_ok 101; RESULT="UNATTENDED-APPROVE: merge pr=101"; }
turn_ticket_12_2() { set_pr 101 OPEN "$SHA_B"; rex_ok 101; RESULT="Refused: behind base. Updated.
UNATTENDED-APPROVE: merge pr=101"; }
turn_ticket_12_3() { set_pr 101 OPEN "$SHA_C"; rex_ok 101; RESULT="Refused again. Updated.
UNATTENDED-APPROVE: merge pr=101"; }
turn_ticket_12_4() { set_pr 101 OPEN "$SHA_A"; rex_ok 101; RESULT="Refused again.
UNATTENDED-APPROVE: merge pr=101"; }
