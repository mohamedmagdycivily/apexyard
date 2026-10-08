# budget — a turn hits its budget twice. Retry once after progress, then halt.
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { SUBTYPE=error_max_budget_usd; COST=15; RESULT=""; }
turn_ticket_12_2() { SUBTYPE=error_max_budget_usd; COST=15; RESULT=""; }
