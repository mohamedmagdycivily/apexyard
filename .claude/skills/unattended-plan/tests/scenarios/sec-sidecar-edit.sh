# sec-sidecar-edit — the child edits the sidecar during the run (review of #7, L1).
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { jq '.config.max_run_usd = 99999' "$SIDECAR_FILE" > "$SIDECAR_FILE.t" && mv "$SIDECAR_FILE.t" "$SIDECAR_FILE"
  RESULT="UNATTENDED-ASK: Continue? | options: yes; no | recommended: yes"; }
