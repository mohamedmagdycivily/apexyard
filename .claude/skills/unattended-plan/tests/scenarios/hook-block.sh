# hook-block — block-main-push.sh blocks a push: halt.
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { TOOL_TEXT="BLOCKED: Cannot push directly to a protected branch ('main')."
  RESULT="The push was blocked.
UNATTENDED-ASK: Push to main? | options: yes; no | recommended: no"; }
