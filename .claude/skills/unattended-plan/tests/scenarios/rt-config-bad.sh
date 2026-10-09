# rt-config-bad — a child sets turn_timeout_s to 0 and max_run_usd to a word:
# both are ignored (security review of #14, S2).
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, TOOL_TEXT,
# ERR_TEXT and HANG.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { jq '.config.turn_timeout_s = 0 | .config.max_run_usd = "lots"' "$SIDECAR_FILE" > "$SIDECAR_FILE.t" && mv "$SIDECAR_FILE.t" "$SIDECAR_FILE"
  RESULT="UNATTENDED-ASK: Go? | options: yes; no | recommended: yes"; }
turn_ticket_12_2() { set_pr 101 OPEN "$SHA_A"; rex_ok 101; RESULT="UNATTENDED-APPROVE: merge pr=101"; }
turn_ticket_12_3() { set_pr 101 MERGED "$SHA_A"; set_issue 12 CLOSED; RESULT="UNATTENDED-NEXT: ticket=12 done pr=101"; }
