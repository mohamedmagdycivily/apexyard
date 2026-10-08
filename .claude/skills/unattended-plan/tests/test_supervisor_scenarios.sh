#!/bin/bash
# test_supervisor_scenarios.sh — drive bin/unattended-supervisor end to end
# against fake-claude.sh and fake-gh.sh (PRD-001 FR-8, AgDR-0222).
#
# Each scenario under scenarios/ scripts the child turns. The assertions read
# the fake's call log, the run state, approvals.jsonl, and the exit code.
#
# Exit 0 when every case passes.

# Variables such as RC, SIDE, and SHA_* are read inside eval'd check strings.
# shellcheck disable=SC2034
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
UT_SUPERVISOR="$ROOT/bin/unattended-supervisor"
# shellcheck source=_lib-unattended-test.sh
. "$HERE/_lib-unattended-test.sh"

# Pretend we run inside a parent Claude session, so the scrub is observable.
export CLAUDE_CODE_SESSION_ID=parent-session-id
export CLAUDECODE=1
unset APEXYARD_UNATTENDED_SUPERVISED APEXYARD_APPROVAL_PROXY

run_scenario() { # <scenario> [supervisor args...] → sets RC, OUT
  export FAKE_SCENARIO="$HERE/scenarios/$1.sh"; shift
  OUT="$(cd "$SB" && ut_supervisor "$@" 2>&1)"; RC=$?
}

state() { jq -r "$@" "$STATE_DIR/state.json"; }
two_tickets() { # <13 blocked_by json>
  set_issue 12 OPEN; set_issue 13 OPEN
  ut_sidecar "[{\"n\":12,\"title\":\"Sign-up\",\"blocked_by\":[]},{\"n\":13,\"title\":\"Availability\",\"blocked_by\":${1:-[12]}}]"
  ut_token
}
cleanup() { [ -n "${SB:-}" ] && rm -rf "$SB"; }

# ------------------------------------------------------------------ happy --
echo "== happy"
ut_sandbox; two_tickets; run_scenario happy
check "happy: exit 0" '[ "$RC" = 0 ]' "$OUT"
check "happy: both tickets done" '[ "$(state "[.tickets[].status] | join(\",\")")" = "done,done" ]'
check "happy: recommended option sent" 'calls_for ticket_13 | sed -n 2p | grep -q "Go with the recommended option: B. Continue."'
check "happy: /approve-design sent with repo" 'calls_for ticket_13 | sed -n 3p | cut -f4 | grep -qx "/approve-design acme/widget#102"'
check "happy: /approve-merge sent with repo" 'calls_for ticket_12 | sed -n 2p | cut -f4 | grep -qx "/approve-merge acme/widget#101"'
check "happy: one session per ticket, resumed after turn 1" \
  '[ "$(calls_for ticket_12 | cut -f2 | tr "\n" " ")" = "new resume " ] && [ "$(calls_for ticket_12 | cut -f3 | sort -u | wc -l)" = 1 ]'
check "happy: ticket 13 gets a different session" '[ "$(calls_for ticket_12 | head -1 | cut -f3)" != "$(calls_for ticket_13 | head -1 | cut -f3)" ]'
check "happy: approvals.jsonl has design + 2 merges" \
  '[ "$(jq -r "select(.result == \"sent\") | \"\(.kind):\(.pr)\"" "$STATE_DIR/approvals.jsonl" | tr "\n" " ")" = "merge:101 design:102 merge:102 " ]'
check "happy: approval line records head, rex, run" \
  '[ "$(jq -r "select(.pr == 101 and .result == \"sent\") | \"\(.head)/\(.rex)/\(.run)/\(.started_by)\"" "$STATE_DIR/approvals.jsonl")" = "$SHA_A/$SHA_A/test-run/owner-session" ]'
check "happy: parent session env scrubbed in child" '! grep -q "session_id=parent-session-id" "$FAKE_DIR/env.log"'
check "happy: proxy env names run, prd, ticket, owner" \
  'grep -q "proxy=unattended-plan run=test-run prd=$PRD_FILE ticket=12 started_by=owner-session" "$FAKE_DIR/env.log"'
check "happy: supervised flag set in child" 'grep -q "supervised=1" "$FAKE_DIR/env.log"'
check "happy: child flags (hooks on, no prompts, no AskUserQuestion)" \
  'grep "^ticket_12" "$FAKE_DIR/argv.log" | head -1 | grep -q -- "--permission-mode acceptEdits --permission-prompts none" &&
   grep "^ticket_12" "$FAKE_DIR/argv.log" | head -1 | grep -q -- "--disallowedTools AskUserQuestion" &&
   ! grep -qE -- "--bare|--safe-mode|bypassPermissions" "$FAKE_DIR/argv.log"'
check "happy: child rules appended on every turn" '[ "$(grep -c -- "--append-system-prompt" "$FAKE_DIR/argv.log")" = "$(wc -l < "$FAKE_DIR/argv.log")" ]'
check "happy: branch recorded" '[ "$(state ".tickets[0].branch")" = "feature/GH-12-signup" ]'
check "happy: summary written" 'grep -q "| #12 | Sign-up | done | feature/GH-12-signup | \[#101\]" "$STATE_DIR/summary.md"'
check "happy: lock released" '[ ! -f "$STATE_DIR/lock" ]'
check "happy: per-turn stream logs kept" '[ -f "$STATE_DIR/logs/ticket-12/turn-1.jsonl" ] && [ -f "$STATE_DIR/logs/ticket-13/turn-4.jsonl" ]'
cleanup

# ------------------------------------------------------------- sequential --
echo "== sequential"
ut_sandbox; two_tickets; run_scenario sequential
check "sequential: exit 0" '[ "$RC" = 0 ]' "$OUT"
check "sequential: NEXT with open ticket is refused" 'calls_for ticket_12 | sed -n 3p | grep -q "ticket #12 is still open"'
check "sequential: ticket 13 started only after #12 closed and PR merged" \
  'grep -qx "issue 12 CLOSED" "$FAKE_DIR/snap.ticket_13" && grep -qx "pr 101 MERGED" "$FAKE_DIR/snap.ticket_13"'
check "sequential: every ticket-12 call precedes every ticket-13 call" \
  '[ "$(cut -f1 "$FAKE_DIR/calls.log" | tr "\n" " ")" = "ticket_12 ticket_12 ticket_12 ticket_13 ticket_13 " ]'
cleanup

# ------------------------------------------------- planning-files-tickets --
echo "== planning-files-tickets"
ut_sandbox; ut_token; run_scenario planning-files-tickets --plan-only
SIDE="$SB/docs/PRD-001-x.unattended.json"
check "planning: exit 0" '[ "$RC" = 0 ]' "$OUT"
check "planning: sidecar written next to the PRD" '[ -f "$SIDE" ]'
check "planning: order follows blocked-by" '[ "$(jq -c "[.tickets[].n]" "$SIDE")" = "[12,13]" ]'
check "planning: blocked_by parsed" '[ "$(jq -c ".tickets[1].blocked_by" "$SIDE")" = "[12]" ]'
check "planning: epic recorded" '[ "$(jq -r .epic "$SIDE")" = 11 ]'
check "planning: ui label detected" '[ "$(jq -r ".tickets[0].ui" "$SIDE")" = true ]'
check "planning: config defaults written" '[ "$(jq -r ".config.max_run_usd" "$SIDE")" = 300 ]'
check "planning: --plan-only starts no ticket session" '! grep -q "^ticket_" "$FAKE_DIR/calls.log"'
check "planning: planning prompt names repo and PRD" 'calls_for planning | head -1 | grep -q "acme/widget" && calls_for planning | head -1 | grep -q "PRD-001-x.md"'
cleanup

# ------------------------------------------------- planning-tickets-exist --
echo "== planning-tickets-exist"
ut_sandbox; ut_token; set_issue 11 OPEN; set_issue 12 CLOSED; set_issue 13 OPEN; set_issue 14 OPEN
run_scenario planning-tickets-exist --plan-only
check "exist: exit 0" '[ "$RC" = 0 ]' "$OUT"
check "exist: closed ticket dropped" '[ "$(jq -c "[.tickets[].n]" "$SB/docs/PRD-001-x.unattended.json")" = "[13,14]" ]'
check "exist: ask answered with recommendation" 'calls_for planning | sed -n 2p | grep -q "Go with the recommended option: no. Continue."'
cleanup

# ---------------------------------------------------- planning-bad-number --
echo "== planning-bad-number"
ut_sandbox; ut_token; set_issue 12 OPEN; run_scenario planning-bad-number --plan-only
check "bad-number: unknown ticket sent back" 'calls_for planning | sed -n 2p | grep -q "do not exist in acme/widget: #99"'
check "bad-number: second report accepted" '[ "$RC" = 0 ] && [ "$(jq -c "[.tickets[].n]" "$SB/docs/PRD-001-x.unattended.json")" = "[12]" ]' "$OUT"
cleanup

# ---------------------------------------------------- existing sidecar wins --
echo "== sidecar wins"
ut_sandbox; two_tickets; run_scenario planning-files-tickets --plan-only
check "sidecar-wins: no planning session when the sidecar exists" '[ "$RC" = 0 ] && [ ! -s "$FAKE_DIR/calls.log" ]' "$OUT"
cleanup

# ------------------------------------------------------ --tickets filter --
echo "== tickets filter"
ut_sandbox; two_tickets '[]'; run_scenario happy --tickets 12
check "filter: only #12 runs" '[ "$RC" = 0 ] && ! grep -q "^ticket_13" "$FAKE_DIR/calls.log" && [ "$(state ".tickets | length")" = 1 ]' "$OUT"
cleanup

# ---------------------------------------------------- blocked-independent --
echo "== blocked-independent"
ut_sandbox; two_tickets '[]'; run_scenario blocked-independent
check "blocked-indep: exit 0" '[ "$RC" = 0 ]' "$OUT"
check "blocked-indep: #12 needs owner, #13 done" '[ "$(state "[.tickets[].status] | join(\",\")")" = "needs_owner,done" ]'
check "blocked-indep: needs-owner item keeps the detail" '[ "$(state ".needs_owner[0].code + \" \" + .needs_owner[0].detail")" = "credentials the payment API key is not set" ]'
check "blocked-indep: summary lists the item" 'grep -q "credentials" "$STATE_DIR/summary.md"'
cleanup

# ------------------------------------------------------ blocked-dependent --
echo "== blocked-dependent"
ut_sandbox; two_tickets '[12]'; run_scenario blocked-dependent
check "blocked-dep: halts (exit 1)" '[ "$RC" = 1 ]' "$OUT"
check "blocked-dep: #13 never starts" '! grep -q "^ticket_13" "$FAKE_DIR/calls.log"'
check "blocked-dep: halt reason recorded" 'state ".halted" | grep -q "later ticket depends"'
check "blocked-dep: summary has the resume command" 'grep -q -- "--resume" "$STATE_DIR/summary.md"'
cleanup

# -------------------------------------------------------------- no-endline --
echo "== no-endline"
ut_sandbox; two_tickets; run_scenario no-endline
check "no-endline: halts" '[ "$RC" = 1 ]' "$OUT"
check "no-endline: first reply is the nudge" 'calls_for ticket_12 | sed -n 2p | grep -q "did not end with exactly one UNATTENDED- line"'
check "no-endline: decide call made once" '[ "$(calls_for decide | wc -l)" = 1 ]'
check "no-endline: decide reply sent" 'calls_for ticket_12 | sed -n 3p | grep -q "Continue and open the PR."'
check "no-endline: needs-owner recorded" '[ "$(state ".needs_owner | length")" -ge 1 ]'
cleanup

# ----------------------------------------------------------- not-last-line --
echo "== not-last-line"
ut_sandbox; two_tickets '[]'; run_scenario not-last-line --tickets 12
check "not-last: nudged, then approved" 'calls_for ticket_12 | sed -n 2p | grep -q "did not end with" && calls_for ticket_12 | sed -n 3p | grep -q "^.*/approve-merge acme/widget#101$"' "$(cat "$FAKE_DIR/calls.log")"
check "not-last: done" '[ "$RC" = 0 ]' "$OUT"
cleanup

# --------------------------------------------------------------- stop-file --
echo "== stop-file"
ut_sandbox; two_tickets; run_scenario stop-file
check "stop: halts after the current turn" '[ "$RC" = 1 ] && [ "$(calls_for ticket_12 | wc -l)" = 1 ]' "$OUT"
check "stop: reason recorded" 'state ".halted" | grep -q "stop file"'
check "stop: summary written" '[ -f "$STATE_DIR/summary.md" ]'
cleanup

# ----------------------------------------------------------- token-removed --
echo "== token-removed"
ut_sandbox; two_tickets; run_scenario token-removed
check "token: halts" '[ "$RC" = 1 ]' "$OUT"
check "token: no /approve-merge sent" '! grep -q "/approve-merge" "$FAKE_DIR/calls.log"'
check "token: no approval recorded" '[ ! -s "$STATE_DIR/approvals.jsonl" ]'
cleanup

# --------------------------------------------------------------- stale-rex --
echo "== stale-rex"
ut_sandbox; two_tickets '[]'; run_scenario stale-rex --tickets 12
check "stale-rex: re-review requested" 'calls_for ticket_12 | sed -n 2p | grep -q "does not match HEAD $SHA_C"'
check "stale-rex: merge sent after re-review" 'calls_for ticket_12 | sed -n 3p | grep -q "/approve-merge acme/widget#101"'
check "stale-rex: done" '[ "$RC" = 0 ]' "$OUT"
cleanup

# ------------------------------------------------------------------ ci-red --
echo "== ci-red"
ut_sandbox; two_tickets; run_scenario ci-red
check "ci-red: first red gets a fix request" 'calls_for ticket_12 | sed -n 2p | grep -q "CI is red on PR #101"'
check "ci-red: halts on the second red" '[ "$RC" = 1 ] && state ".halted" | grep -q "CI red twice"' "$OUT"
check "ci-red: no /approve-merge sent" '! grep -q "/approve-merge" "$FAKE_DIR/calls.log"'
cleanup

# ----------------------------------------------------------- merge-refused --
echo "== merge-refused"
ut_sandbox; two_tickets; run_scenario merge-refused
check "refused: halts after three cycles" '[ "$RC" = 1 ] && state ".halted" | grep -q "refused three times"' "$OUT"
check "refused: three merges were sent" '[ "$(grep -c "/approve-merge" "$FAKE_DIR/calls.log")" = 3 ]'
cleanup

# -------------------------------------------------------------- hook-block --
echo "== hook-block"
ut_sandbox; two_tickets; run_scenario hook-block
check "hook-block: halts on block-main-push" '[ "$RC" = 1 ] && state ".halted" | grep -q "block-main-push.sh"' "$OUT"
check "hook-block: nothing more sent" '[ "$(calls_for ticket_12 | wc -l)" = 1 ]'
cleanup

# ------------------------------------------------------------------ budget --
echo "== budget"
ut_sandbox; two_tickets; run_scenario budget
check "budget: retried once" 'calls_for ticket_12 | sed -n 2p | grep -q "stopped early (error_max_budget_usd)"'
check "budget: halts after the second failure" '[ "$RC" = 1 ] && [ "$(calls_for ticket_12 | wc -l)" = 2 ]' "$OUT"
check "budget: cost summed" '[ "$(state ".cost_usd")" = 30 ]'
cleanup

# ----------------------------------------------------------------- dry-run --
echo "== dry-run"
ut_sandbox; two_tickets; run_scenario happy --dry-run
check "dry-run: exit 0" '[ "$RC" = 0 ]' "$OUT"
check "dry-run: runs no model" '[ ! -s "$FAKE_DIR/calls.log" ]'
check "dry-run: prints the plan" 'printf "%s" "$OUT" | grep -q "#13  Availability  blocked by #12"'
check "dry-run: prints the child call and replies" 'printf "%s" "$OUT" | grep -q -- "--permission-prompts none" && printf "%s" "$OUT" | grep -q "/approve-merge acme/widget#<p>"'
check "dry-run: writes no state" '[ ! -f "$STATE_DIR/state.json" ]'
cleanup

# --------------------------------------------------------------- ampersand --
echo "== ampersand"
ut_sandbox; set_issue 12 OPEN
printf 'Run npm test && npm run lint before you push.\nUse A&B naming.\n' > "$SB/docs/exec.md"
jq -n '{config:{execution_prompt:"exec.md", max_turn_usd:15, max_ticket_usd:60, max_run_usd:300, turn_timeout_s:60, notify_webhook:""}, epic:11, tickets:[{n:12, title:"Search & filter", blocked_by:[]}]}' > "$SB/docs/PRD-001-x.unattended.json"
ut_token; run_scenario ampersand
P="$FAKE_DIR/prompt.ticket_12.1"
check "ampersand: title verbatim" 'grep -qF "#12: Search & filter" "$P"' "$(head -3 "$P")"
check "ampersand: execution prompt verbatim" 'grep -qF "Run npm test && npm run lint before you push." "$P" && grep -qF "Use A&B naming." "$P"'
check "ampersand: no placeholder leaked" '! grep -q "{{" "$P"'
check "ampersand: execution prompt scoped to the ticket" 'grep -qF "This session covers only ticket #12." "$P"'
check "ampersand: done" '[ "$RC" = 0 ]' "$OUT"
cleanup

# ---------------------------------------------------------------- wrong-pr --
echo "== wrong-pr"
ut_sandbox; set_issue 12 OPEN; ut_sidecar '[{"n":12,"title":"Sign-up","blocked_by":[]}]'; ut_token
run_scenario wrong-pr
check "wrong-pr: a merged PR of another ticket is refused" 'calls_for ticket_12 | sed -n 2p | grep -q "is not the PR for ticket #12"'
check "wrong-pr: the right PR completes the ticket" '[ "$RC" = 0 ] && [ "$(state ".tickets[0].pr")" = 101 ]' "$OUT"
cleanup

# -------------------------------------------------------------- ask-no-rec --
echo "== ask-no-rec"
ut_sandbox; two_tickets '[]'; run_scenario ask-no-rec --tickets 12
check "ask-no-rec: decide call answers" '[ "$(calls_for decide | wc -l)" = 1 ] && calls_for ticket_12 | sed -n 2p | grep -q "Use: No bookings yet."'
check "ask-no-rec: done" '[ "$RC" = 0 ]' "$OUT"
cleanup

# ---------------------------------------------------------------- rehearse --
echo "== rehearse"
ut_sandbox; two_tickets '[]'; printf '\n\n' > "$SB/keys"
UNATTENDED_TTY="$SB/keys" run_scenario happy --tickets 12 --rehearse
check "rehearse: Enter sends the approval" '[ "$RC" = 0 ] && printf "%s" "$OUT" | grep -q "About to send: /approve-merge acme/widget#101"' "$OUT"
cleanup
ut_sandbox; two_tickets '[]'; printf 'q\n' > "$SB/keys"
UNATTENDED_TTY="$SB/keys" run_scenario happy --tickets 12 --rehearse
check "rehearse: q stops before sending" '[ "$RC" = 1 ] && ! grep -q "/approve-merge" "$FAKE_DIR/calls.log" && state ".halted" | grep -q "rehearsal stopped"' "$OUT"
cleanup

# --------------------------------------------------------------- refusals --
echo "== refusals"
ut_sandbox; two_tickets
OUT="$(cd "$SB" && APEXYARD_UNATTENDED_SUPERVISED=1 ut_supervisor 2>&1)"; RC=$?
check "refuse: supervisor will not start inside a supervised child" '[ "$RC" = 2 ] && printf "%s" "$OUT" | grep -q "supervised child"'
rm -f "$STATE_DIR/run.token"; export FAKE_SCENARIO="$HERE/scenarios/happy.sh"
OUT="$(cd "$SB" && ut_supervisor 2>&1)"; RC=$?
check "refuse: no run token, no run" '[ "$RC" = 2 ] && printf "%s" "$OUT" | grep -q "no run token"'
ut_token; sleep 300 & holder=$!; printf '%s\n' "$holder" > "$STATE_DIR/lock"
OUT="$(cd "$SB" && ut_supervisor 2>&1)"; RC=$?
check "refuse: a live lock blocks a second supervisor" '[ "$RC" = 3 ] && printf "%s" "$OUT" | grep -q "PID $holder"'
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
cleanup

ut_done
