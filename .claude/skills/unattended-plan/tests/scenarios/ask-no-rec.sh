# ask-no-rec — a question with no recommendation goes to the decide call.
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { RESULT="UNATTENDED-ASK: What should the empty state say?"; }
turn_ticket_12_2() { set_pr 101 OPEN "$SHA_A"; rex_ok 101; RESULT="UNATTENDED-APPROVE: merge pr=101"; }
turn_ticket_12_3() { set_pr 101 MERGED "$SHA_A"; set_issue 12 CLOSED; RESULT="UNATTENDED-NEXT: ticket=12 done pr=101"; }
decide_1() { RESULT='{"action":"reply","reply":"Use: No bookings yet.","reason":"copy choice"}'; }
