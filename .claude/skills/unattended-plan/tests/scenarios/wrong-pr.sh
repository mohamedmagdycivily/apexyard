# wrong-pr — NEXT names a merged PR that belongs to another ticket.
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { set_pr 90 MERGED "$SHA_C" feature/GH-7-old; set_issue 12 CLOSED
  RESULT="UNATTENDED-NEXT: ticket=12 done pr=90"; }
turn_ticket_12_2() { set_pr 101 MERGED "$SHA_A"; RESULT="UNATTENDED-NEXT: ticket=12 done pr=101"; }
