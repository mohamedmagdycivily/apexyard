# sec-fork-pr — a fork's PR with a matching branch name is refused (A5).
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { set_pr 101 OPEN "$SHA_A" feature/GH-12-x false evil/widget; rex_ok 101; RESULT="UNATTENDED-APPROVE: merge pr=101"; }
turn_ticket_12_2() { RESULT="UNATTENDED-BLOCKED: ambiguous-scope stop here"; }
