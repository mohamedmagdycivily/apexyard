# no-endline — the session never ends with a protocol line. Nudge, decide
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
# call, then halt.
turn_ticket_12_1() { RESULT="I worked on it."; }
turn_ticket_12_2() { RESULT="Still working."; }
turn_ticket_12_3() { RESULT="More work, no line."; }
turn_ticket_12_4() { RESULT="Even more."; }
decide_1() { RESULT='{"action":"reply","reply":"Continue and open the PR.","reason":"no end line"}'; }
