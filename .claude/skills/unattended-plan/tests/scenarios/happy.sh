# happy — two tickets, #13 blocked by #12. Ticket 12 asks for merge once.
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
# Ticket 13 asks a question with a recommendation, needs design approval,
# then merge.
turn_ticket_12_1() { set_pr 101 OPEN "$SHA_A" feature/GH-12-signup; rex_ok 101; ci 101 pass
  RESULT="Built and reviewed.
UNATTENDED-STATUS: rex=approved round=1 ci=green
UNATTENDED-APPROVE: merge pr=101"; }
turn_ticket_12_2() { set_pr 101 MERGED "$SHA_A" feature/GH-12-signup; set_issue 12 CLOSED
  RESULT="Merged, QA passed, closed.
UNATTENDED-NEXT: ticket=12 done pr=101"; }
turn_ticket_13_1() { RESULT="Which date picker?
UNATTENDED-ASK: Which picker? | options: A; B | recommended: B"; }
turn_ticket_13_2() { set_pr 102 OPEN "$SHA_B" feature/GH-13-availability; rex_ok 102
  RESULT="UNATTENDED-APPROVE: design pr=102"; }
turn_ticket_13_3() { RESULT="Design approved.
UNATTENDED-APPROVE: merge pr=102"; }
turn_ticket_13_4() { set_pr 102 MERGED "$SHA_B" feature/GH-13-availability; set_issue 13 CLOSED
  RESULT="UNATTENDED-NEXT: ticket=13 done pr=102"; }
