# blocked-dependent — #12 needs credentials and #13 is blocked by #12: halt.
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { RESULT="I need an API key.
UNATTENDED-BLOCKED: credentials the payment API key is not set"; }
turn_ticket_13_1() { set_pr 102 OPEN "$SHA_B"; rex_ok 102; RESULT="UNATTENDED-APPROVE: merge pr=102"; }
turn_ticket_13_2() { set_pr 102 MERGED "$SHA_B"; set_issue 13 CLOSED; RESULT="UNATTENDED-NEXT: ticket=13 done pr=102"; }
