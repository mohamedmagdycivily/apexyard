# sec-sidecar-edit — the child edits the sidecar's ticket plan during the run
# (review of #7, L1). A config-only edit is allowed since #13.
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, and TOOL_TEXT.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { jq '.tickets[0].owner_only = true' "$SIDECAR_FILE" > "$SIDECAR_FILE.t" && mv "$SIDECAR_FILE.t" "$SIDECAR_FILE"
  RESULT="UNATTENDED-ASK: Continue? | options: yes; no | recommended: yes"; }
