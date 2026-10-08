# planning-files-tickets — no tickets exist. The planning session files the
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
# epic and two stories (13 blocked by 12) and reports them out of order.
turn_planning_1() {
  set_issue 11 OPEN "[Feature] Epic"
  set_issue 12 OPEN "[Feature] Sign-up" "Refs #11" "ui"
  set_issue 13 OPEN "[Feature] Availability" "Refs #11

Blocked by #12"
  RESULT="Filed the epic and two stories.
UNATTENDED-TICKETS: epic=11 tickets=13,12"; }
