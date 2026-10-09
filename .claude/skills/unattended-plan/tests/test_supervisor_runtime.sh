#!/bin/bash
# test_supervisor_runtime.sh — the fixes for the supervisor bugs found in the
# first real run (#13): session-cost deltas, a success result over a timeout,
# the hung-process guard, background-agent stops, live limits, the retry
# notice, and the stopped status. Driven end to end against fake-claude.sh and
# fake-gh.sh (AgDR-0222).
#
# Exit 0 when every case passes.

# Variables such as RC and SHA_* are read inside eval'd check strings.
# shellcheck disable=SC2034
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
UT_SUPERVISOR="$ROOT/bin/unattended-supervisor"
# shellcheck source=_lib-unattended-test.sh
. "$HERE/_lib-unattended-test.sh"
export CLAUDE_CODE_SESSION_ID=parent-session-id
unset APEXYARD_UNATTENDED_SUPERVISED APEXYARD_APPROVAL_PROXY DISPLAY WAYLAND_DISPLAY

run_scenario() { # <scenario> [supervisor args...] → sets RC, OUT
  export FAKE_SCENARIO="$HERE/scenarios/$1.sh"; shift
  OUT="$(cd "$SB" && ut_supervisor "$@" 2>&1)"; RC=$?
}
state() { jq -r "$@" "$STATE_DIR/state.json"; }
one_ticket() { # [turn_timeout_s]
  set_issue 12 OPEN
  jq -n --argjson to "${1:-60}" '{config:{execution_prompt:"", max_turn_usd:15, max_ticket_usd:60, max_run_usd:300, turn_timeout_s:$to, notify_webhook:""}, epic:11, tickets:[{n:12, title:"Sign-up", blocked_by:[]}]}' \
    > "$SB/docs/PRD-001-x.unattended.json"
  ut_token
}
cleanup() { [ -n "${SB:-}" ] && rm -rf "$SB"; }

echo "== cost delta"
ut_sandbox; one_ticket; run_scenario rt-cost-delta
check "cost: the ticket costs the session's last total (7), not the sum of totals (18)" '[ "$(state ".tickets[0].cost")" = 7 ] && [ "$(state ".cost_usd")" = 7 ]' "$(state '.tickets[0].cost, .cost_usd')"
check "cost: the log shows per-turn deltas and the session total" 'grep -q "ok=1 cost=1.000000 session_total=7" "$STATE_DIR/supervisor.log"'
check "cost: run done" '[ "$RC" = 0 ]' "$OUT"
cleanup

echo "== a success result wins over the timeout"
ut_sandbox; one_ticket 3; START=$SECONDS; run_scenario rt-timeout-success
check "timeout: the turn with a success result is ok" '[ "$RC" = 0 ] && grep -q "success result kept although the process exited 124" "$STATE_DIR/supervisor.log"' "$OUT"
check "timeout: the approval was still sent" 'calls_for ticket_12 | sed -n 2p | grep -q "/approve-merge acme/widget#101"'
cleanup

echo "== hung process after its result"
ut_sandbox; one_ticket 60; START=$SECONDS
UNATTENDED_RESULT_GRACE_S=2 UNATTENDED_POLL_S=1 run_scenario rt-timeout-success
check "hang: SIGINT after the quiet grace period" 'grep -q "no output for 2s, but the process has not exited: sending SIGINT" "$STATE_DIR/supervisor.log"' "$(tail -5 "$STATE_DIR/supervisor.log")"
check "hang: the run did not wait for the 60 s timeout" '[ $((SECONDS - START)) -lt 40 ] && [ "$RC" = 0 ]' "elapsed $((SECONDS - START))s; $OUT"
cleanup

echo "== background agent stopped"
ut_sandbox; one_ticket; run_scenario rt-bg-stopped
check "bg: the child env waits for background work" 'grep -q "bgceiling=0" "$FAKE_DIR/env.log" && ! grep -q "bgceiling=unset" "$FAKE_DIR/env.log"'
check "bg: the next prompt asks for a foreground redo, not a nudge" 'grep -q "stopped your background agent" "$FAKE_DIR/prompt.ticket_12.2" && ! grep -q "did not end with" "$FAKE_DIR/prompt.ticket_12.2"'
check "bg: a stop on a finished ticket (NEXT) does not block it" '[ "$RC" = 0 ] && [ "$(state ".tickets[0].status")" = done ]' "$OUT"
cleanup

echo "== live limits"
ut_sandbox; one_ticket; export SIDECAR_FILE="$SB/docs/PRD-001-x.unattended.json"; run_scenario rt-live-config
check "config: a limit edit mid-run does not halt the run" '[ "$RC" = 0 ] && [ "$(state ".halted")" = null ]' "$OUT"
check "config: each change is logged" 'grep -q "CONFIG: max_turn_usd 15 -> 33" "$STATE_DIR/supervisor.log" && grep -q "CONFIG: max_run_usd 300 -> 999" "$STATE_DIR/supervisor.log"'
check "config: the next turn uses the new per-turn budget" 'grep "^ticket_12" "$FAKE_DIR/argv.log" | sed -n 2p | grep -q -- "--max-budget-usd 33"'
cleanup

echo "== retry notice"
ut_sandbox; one_ticket; run_scenario budget
check "retry: the last retry is logged" 'grep -q "RETRY ticket #12 (last retry): error_max_budget_usd" "$STATE_DIR/supervisor.log"'
cleanup

echo "== stopped status + log text"
ut_sandbox; one_ticket; run_scenario stop-file
check "stopped: a halt marks the ticket in flight stopped" '[ "$(state ".tickets[0].status")" = stopped ]' "$(state '.tickets[0].status')"
check "log: prompt= shows the first non-empty line" 'grep "TURN unattended:widget:PRD-001-x:ticket-12 #1 (new)" "$STATE_DIR/supervisor.log" | grep -q "prompt=# Ticket session for #12"'
jq '.tickets[0].turn_started = "09:41" | .tickets[0].turns = 2' "$STATE_DIR/state.json" > "$SB/s" && mv "$SB/s" "$STATE_DIR/state.json"
OUT="$("$UT_SUPERVISOR" status --prd "$PRD_FILE" --project widget --ops-root "$OPS_DIR" 2>&1)"
check "status: a ticket in flight shows its running turn" 'printf "%s" "$OUT" | grep -q "turn 3 running since 09:41"' "$OUT"
jq '.tickets[0].turn_started = null' "$STATE_DIR/state.json" > "$SB/s" && mv "$SB/s" "$STATE_DIR/state.json"
ut_token; export FAKE_SCENARIO="$HERE/scenarios/resume.sh"
OUT="$(cd "$SB" && ut_supervisor --resume 2>&1)"; RC=$?
check "stopped: --resume picks the stopped ticket up as running (no PR yet: fresh session)" 'grep -q "RECONCILE #12 running with no open PR: fresh session" "$STATE_DIR/supervisor.log" && [ "$(calls_for ticket_12 | wc -l)" -ge 2 ]' "$(cut -f1-3 "$FAKE_DIR/calls.log")"
cleanup

ut_done
