# rt-live-config — the owner raises limits in the sidecar mid-run. No halt;
# the next turn uses the new values (#13).
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, TOOL_TEXT,
# ERR_TEXT and HANG.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { jq '.config.max_turn_usd = 33 | .config.max_run_usd = 999' "$SIDECAR_FILE" > "$SIDECAR_FILE.t" && mv "$SIDECAR_FILE.t" "$SIDECAR_FILE"
  RESULT="UNATTENDED-ASK: Go? | options: yes; no | recommended: yes"; }
turn_ticket_12_2() { set_pr 101 OPEN "$SHA_A"; rex_ok 101; RESULT="UNATTENDED-APPROVE: merge pr=101"; }
turn_ticket_12_3() { set_pr 101 MERGED "$SHA_A"; set_issue 12 CLOSED; RESULT="UNATTENDED-NEXT: ticket=12 done pr=101"; }
