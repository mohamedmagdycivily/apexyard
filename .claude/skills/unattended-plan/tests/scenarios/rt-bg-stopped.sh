# rt-bg-stopped — the CLI stopped a background agent; the turn ends with a
# progress note. The supervisor asks for a foreground redo, not a nudge (#13).
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, TOOL_TEXT,
# ERR_TEXT and HANG.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { ERR_TEXT='Background tasks still running 10m after the last turn (subagent "Build chat"); stopping them.'
  RESULT="The build agent is still running."; }
turn_ticket_12_2() { set_pr 101 OPEN "$SHA_A"; rex_ok 101; RESULT="Redone in the foreground.
UNATTENDED-APPROVE: merge pr=101"; }
turn_ticket_12_3() { set_pr 101 MERGED "$SHA_A"; set_issue 12 CLOSED
  ERR_TEXT='Background tasks still running 10m after the last turn (subagent "qa"); stopping them.'
  RESULT="UNATTENDED-NEXT: ticket=12 done pr=101"; }
