#!/bin/bash
# test_supervisor_ops.sh — the one-command run (#11), prompt text, notifications,
# and the summary layout, driven end to end against fake-claude.sh and
# fake-gh.sh (PRD-001 FR-8, AgDR-0222).
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
# No desktop notifications from the tests, except the case that sets DISPLAY.
unset DISPLAY WAYLAND_DISPLAY

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
# No desktop notifications from the tests, except the case that sets DISPLAY.
unset DISPLAY WAYLAND_DISPLAY

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

# ------------------------------------------------------- #11: one command --
echo "== planning-groups"
ut_sandbox; ut_token
set_issue 11 OPEN "[Feature] Widget MVP (PRD-001 epic)"
set_issue 12 OPEN "[Feature] Sub-epic 1 of 2: Foundation"
set_issue 13 OPEN "[Feature] Sign-up"
set_issue 14 OPEN "[Feature] Payments group" "" "epic"
set_issue 16 OPEN "[Feature] Search"
run_scenario planning-groups --plan-only
check "groups: epic and sub-epics dropped, stories kept" '[ "$(jq -c "[.tickets[].n]" "$SB/docs/PRD-001-x.unattended.json")" = "[13,16]" ]' "$OUT"
check "groups: each drop is logged" '[ "$(grep -c "is an epic or sub-epic, dropped" "$STATE_DIR/supervisor.log")" = 3 ]'
cleanup

echo "== execution prompt by convention"
ut_sandbox; two_tickets '[]'
printf 'PARENT-PROMPT for ticket {{TICKET}} on {{BASE}}\n' > "$SB/execution-prompt-unattended.md"
FAKE_DEFAULT_BRANCH=master run_scenario ampersand --tickets 12
P="$FAKE_DIR/prompt.ticket_12.1"
check "prompt: found in the PRD's parent dir" 'grep -qF "PARENT-PROMPT for ticket 12 on master" "$P"' "$(head -20 "$P")"
check "prompt: discovery logged" 'grep -q "PROMPT: using $SB/execution-prompt-unattended.md (found by convention)" "$STATE_DIR/supervisor.log"'
check "base: ticket prompt names the default branch" 'grep -qF "Start from an updated \`master\` (the default branch)" "$P"'
check "base: child rules name the default branch" 'grep "^ticket_12" "$FAKE_DIR/argv.log" | head -1 | grep -qF "updated \`master\` (the repo" '
cleanup
ut_sandbox; two_tickets '[]'
printf 'PARENT-PROMPT\n' > "$SB/execution-prompt-unattended.md"
printf 'PRD-DIR-PROMPT\n' > "$SB/docs/execution-prompt-unattended.md"
run_scenario ampersand --tickets 12
check "prompt: the PRD's own dir wins over its parent" 'grep -q "PRD-DIR-PROMPT" "$FAKE_DIR/prompt.ticket_12.1" && ! grep -q "PARENT-PROMPT" "$FAKE_DIR/prompt.ticket_12.1"'
cleanup
ut_sandbox; set_issue 12 OPEN
printf 'CONVENTION-PROMPT\n' > "$SB/docs/execution-prompt-unattended.md"
printf 'SIDECAR-PROMPT\n' > "$SB/docs/mine.md"
jq -n '{config:{execution_prompt:"mine.md", max_turn_usd:15, max_ticket_usd:60, max_run_usd:300, turn_timeout_s:60, notify_webhook:""}, epic:11, tickets:[{n:12, title:"Sign-up", blocked_by:[]}]}' > "$SB/docs/PRD-001-x.unattended.json"
ut_token; run_scenario ampersand
check "prompt: the sidecar's execution_prompt wins over the convention" 'grep -q "SIDECAR-PROMPT" "$FAKE_DIR/prompt.ticket_12.1" && ! grep -q "CONVENTION-PROMPT" "$FAKE_DIR/prompt.ticket_12.1"'
cleanup
ut_sandbox; two_tickets '[]'; run_scenario ampersand --tickets 12
check "prompt: no file anywhere falls back to the generic prompt" 'grep -q "Work the ticket" "$FAKE_DIR/prompt.ticket_12.1" && grep -q "PROMPT: no execution prompt" "$STATE_DIR/supervisor.log"'
cleanup

echo "== workspace preflight"
ut_sandbox; two_tickets '[]'
FAKE_BRANCHES=0 run_scenario happy --tickets 12 --workspace "$SB/ws"
check "empty repo: halts before any ticket with the fix named" '[ "$RC" = 1 ] && [ ! -s "$FAKE_DIR/calls.log" ] && state ".needs_owner[0].detail" | grep -q "Push one initial commit"' "$OUT"
cleanup
ut_sandbox; two_tickets '[]'; mkdir -p "$SB/ws"; echo x > "$SB/ws/file"
run_scenario happy --tickets 12 --workspace "$SB/ws"
check "workspace: a non-clone directory halts" '[ "$RC" = 1 ] && state ".halted" | grep -q "workspace is not a clone"' "$OUT"
cleanup
ut_sandbox; two_tickets '[]'
run_scenario happy --tickets 12 --workspace "$SB/ws"
check "workspace: missing clone is cloned, then the ticket runs" '[ "$RC" = 0 ] && [ -d "$SB/ws/.git" ] && grep "^ticket_12" "$FAKE_DIR/argv.log" | head -1 | grep -qF -- "--add-dir $SB/ws"' "$OUT"
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

# ------------------------------------------------------------------ notify --
echo "== notify"
ut_sandbox; two_tickets '[12]'
jq '.config.notify_webhook = "https://hooks.example.test/x"' "$SB/docs/PRD-001-x.unattended.json" > "$SB/t" && mv "$SB/t" "$SB/docs/PRD-001-x.unattended.json"
DISPLAY=:99 run_scenario blocked-dependent
check "notify: desktop notification for the needs-owner item and the halt" 'grep -q "Unattended needs_owner" "$FAKE_DIR/notify.log" && grep -q "Unattended halt" "$FAKE_DIR/notify.log"' "$(cat "$FAKE_DIR/notify.log" 2>/dev/null)"
check "notify: webhook POSTs JSON with the event" 'grep -q "https://hooks.example.test/x" "$FAKE_DIR/curl.log" && grep -q "\"event\":\"needs_owner\"" "$FAKE_DIR/curl.log" && grep -q "\"event\":\"halt\"" "$FAKE_DIR/curl.log"' "$(cat "$FAKE_DIR/curl.log" 2>/dev/null)"
cleanup
ut_sandbox; two_tickets; run_scenario happy
check "notify: no display, no webhook, no notification" '[ ! -s "$FAKE_DIR/notify.log" ] && [ ! -s "$FAKE_DIR/curl.log" ]'
check "notify: done run still exits 0" '[ "$RC" = 0 ]' "$OUT"
cleanup
ut_sandbox; two_tickets '[]'
jq '.config.notify_webhook = "file:///etc/passwd"' "$SB/docs/PRD-001-x.unattended.json" > "$SB/t" && mv "$SB/t" "$SB/docs/PRD-001-x.unattended.json"
run_scenario blocked-independent
check "notify: a non-http webhook is skipped" '[ ! -s "$FAKE_DIR/curl.log" ] && grep -q "notify_webhook is not an http(s) URL" "$STATE_DIR/supervisor.log"'
cleanup
ut_sandbox; two_tickets '[]'
jq '.config.notify_webhook = "https://hooks.example.test/x"' "$SB/docs/PRD-001-x.unattended.json" > "$SB/t" && mv "$SB/t" "$SB/docs/PRD-001-x.unattended.json"
printf '#!/bin/bash\nexit 7\n' > "$SB/bin/curl"
run_scenario happy
check "notify: a failing webhook never fails the run" '[ "$RC" = 0 ] && grep -q "notify_webhook POST failed" "$STATE_DIR/supervisor.log"' "$OUT"
cleanup

ut_sandbox; ut_token
DISPLAY=:99 run_scenario planning-blocked --plan-only
check "notify: a run-level item has no #null in the desktop text" 'grep -q "account: the tracker needs a paid plan" "$FAKE_DIR/notify.log" && ! grep -q "#null" "$FAKE_DIR/notify.log"' "$(cat "$FAKE_DIR/notify.log" 2>/dev/null)"
check "notify: run-level item recorded with ticket null" '[ "$(state ".needs_owner[0].ticket")" = null ] && [ "$RC" = 1 ]' "$OUT"
cleanup
# A run-level item after the sidecar exists (token removed between tickets)
# reaches the webhook with ticket null and a complete JSON body.
ut_sandbox; two_tickets '[]'
jq '.config.notify_webhook = "https://hooks.example.test/x"' "$SB/docs/PRD-001-x.unattended.json" > "$SB/t" && mv "$SB/t" "$SB/docs/PRD-001-x.unattended.json"
run_scenario blocked-independent
check "notify: webhook body is complete JSON" 'grep -q "\"event\":\"needs_owner\".*\"ticket\":12" "$FAKE_DIR/curl.log" && ! grep -q -- "--data  " "$FAKE_DIR/curl.log"' "$(cat "$FAKE_DIR/curl.log" 2>/dev/null)"
cleanup
ut_sandbox; two_tickets '[]'
jq '.config.notify_webhook = "https://hooks.example.test/x"' "$SB/docs/PRD-001-x.unattended.json" > "$SB/t" && mv "$SB/t" "$SB/docs/PRD-001-x.unattended.json"
run_scenario owner-token-gone
check "notify: run-level webhook payload has ticket null" 'grep -q "\"event\":\"halt\"" "$FAKE_DIR/curl.log" && grep "\"ticket\":null" "$FAKE_DIR/curl.log" | grep -q "\"event\":\"halt\""' "$(cat "$FAKE_DIR/curl.log" 2>/dev/null)"
cleanup

# ------------------------------------------------------------ summary layout --
echo "== summary layout"
ut_sandbox; two_tickets '[12]'; run_scenario blocked-dependent
SUM="$STATE_DIR/summary.md"
check "summary: section order" '[ "$(grep "^#" "$SUM" | tr "\n" "|")" = "# Unattended run summary|## Tickets|## Needs owner|## Approvals sent|## Halt reason|## Resume|" ]' "$(grep "^#" "$SUM")"
check "summary: result and counts first" '[ "$(sed -n 3p "$SUM")" = "- Result: **halted**" ] && [ "$(sed -n 4p "$SUM")" = "- Tickets done: 0 of 2" ]' "$(head -6 "$SUM")"
check "summary: ticket table header" 'grep -qx "| Ticket | Title | Status | Branch | PR | Turns | Cost USD | Rex rounds |" "$SUM"'
check "summary: needs-owner item with detail" 'grep -q "^- #12 \`credentials\`: the payment API key is not set" "$SUM"'
check "summary: resume command" 'grep -qx "/unattended-plan $PRD_FILE --resume" "$SUM"'
cleanup
ut_sandbox; two_tickets; run_scenario happy
check "summary: approvals table on a done run" 'grep -qx "| Time | Ticket | PR | Kind | HEAD | Result |" "$STATE_DIR/summary.md" && grep -q "| #12 | #101 | merge | aaaaaaaaaaaa | sent |" "$STATE_DIR/summary.md" && ! grep -q "## Resume" "$STATE_DIR/summary.md"'
check "umask: child sessions run with umask 022" 'grep -q "umask=0022" "$FAKE_DIR/env.log" && ! grep -q "umask=0077" "$FAKE_DIR/env.log"'
check "perms: the state dir is 700" '[ "$(stat -c %a "$STATE_DIR")" = 700 ]'
cleanup

ut_done
