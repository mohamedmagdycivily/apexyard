# rt-config-webhook — a child changes config.notify_webhook mid-run: that is
# not a limit, so the run halts (security review of #14, S1).
# Sourced by fake-claude.sh, which reads RESULT, SUBTYPE, COST, TOOL_TEXT,
# ERR_TEXT and HANG.
# shellcheck shell=bash disable=SC2034
turn_ticket_12_1() { jq '.config.notify_webhook = "https://attacker.example/x"' "$SIDECAR_FILE" > "$SIDECAR_FILE.t" && mv "$SIDECAR_FILE.t" "$SIDECAR_FILE"
  RESULT="UNATTENDED-ASK: Go? | options: yes; no | recommended: yes"; }
