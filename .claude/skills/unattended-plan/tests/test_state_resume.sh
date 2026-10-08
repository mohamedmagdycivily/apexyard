#!/bin/bash
# test_state_resume.sh — state.json, --resume reconciliation, and the lock
# in bin/unattended-supervisor (PRD-001 US-7, FR-8).
#
# Resume trusts the tracker and GitHub over state.json:
#   - a closed ticket with a merged PR is done, whatever the state says
#   - a running ticket with an open PR resumes its own session
#   - a running ticket with no PR starts a fresh session
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
unset APEXYARD_UNATTENDED_SUPERVISED APEXYARD_APPROVAL_PROXY
unset DISPLAY WAYLAND_DISPLAY
export FAKE_SCENARIO="$HERE/scenarios/resume.sh"

# seed_state <ticket-12 json fields> [halted json] — a state.json as a crashed
# or halted run leaves it. Ticket 13 is always pending.
seed_state() {
  mkdir -p "$STATE_DIR"
  jq -n --argjson t12 "$1" --argjson halted "${2:-null}" --arg prd "$PRD_FILE" '
    def blank: {status:"pending", session:null, pr:null, branch:null, turns:0, cost:0,
                rex_rounds:0, ci_red:0, approve_refusals:0, last_line:null, last_sent:null,
                retried:false, fresh:false, owner_only:false, ui:false};
    {run_id:"old-run", prd:$prd, project:"widget", repo:"acme/widget", workspace:"",
     started_by:"owner-session", started_at:"2026-10-08T00:00:00Z", epic:11, cost_usd:1,
     current:12, halted:$halted, planning:null, needs_owner:[],
     tickets:[ (blank + {n:12, title:"Sign-up", blocked_by:[]} + $t12),
               (blank + {n:13, title:"Availability", blocked_by:[12]}) ]}' > "$STATE_DIR/state.json"
}
setup() {
  ut_sandbox; set_issue 12 OPEN; set_issue 13 OPEN
  ut_sidecar '[{"n":12,"title":"Sign-up","blocked_by":[]},{"n":13,"title":"Availability","blocked_by":[12]}]'
  ut_token
}
run() { OUT="$(cd "$SB" && ut_supervisor "$@" 2>&1)"; RC=$?; }
state() { jq -r "$@" "$STATE_DIR/state.json"; }
cleanup() { rm -rf "$SB"; }

echo "== resume: closed ticket with a merged PR is done"
setup; set_issue 12 CLOSED; set_pr 101 MERGED "$SHA_A" feature/GH-12-signup
seed_state '{"status":"running","session":"11111111-1111-1111-1111-111111111111","pr":101}'
run --resume
check "merged: exit 0" '[ "$RC" = 0 ]' "$OUT"
check "merged: ticket 12 gets no session" '! grep -q "^ticket_12" "$FAKE_DIR/calls.log"'
check "merged: ticket 13 ran and is done" '[ "$(state "[.tickets[].status] | join(\",\")")" = "done,done" ]'
check "merged: new run id adopted from the token" '[ "$(state .run_id)" = test-run ]'
cleanup

echo "== resume: closed ticket whose PR state says pending is still done"
setup; set_issue 12 CLOSED; set_pr 101 MERGED "$SHA_A" feature/GH-12-signup
seed_state '{"status":"pending"}'
run --resume
check "pending-but-merged: PR found by branch, no session" '[ "$RC" = 0 ] && ! grep -q "^ticket_12" "$FAKE_DIR/calls.log" && [ "$(state ".tickets[0].pr")" = 101 ]' "$OUT"
cleanup

echo "== resume: running ticket with an open PR resumes its session"
setup; set_pr 101 OPEN "$SHA_A" feature/GH-12-signup
seed_state '{"status":"running","session":"22222222-2222-2222-2222-222222222222","pr":101}'
run --resume
check "open-pr: first call resumes the recorded session" \
  '[ "$(calls_for ticket_12 | head -1 | cut -f2-3)" = "resume	22222222-2222-2222-2222-222222222222" ]' "$(cat "$FAKE_DIR/calls.log" 2>/dev/null)"
check "open-pr: prompt says it was interrupted" 'calls_for ticket_12 | head -1 | grep -q "You were interrupted"'
check "open-pr: ticket 13 starts only after 12 is merged and closed" 'grep -qx "issue 12 CLOSED" "$FAKE_DIR/snap.ticket_13"'
check "open-pr: run done" '[ "$RC" = 0 ]' "$OUT"
cleanup

echo "== resume: merged PR with an open ticket resumes the session (no second PR)"
setup; set_pr 101 MERGED "$SHA_A" feature/GH-12-signup
seed_state '{"status":"running","session":"44444444-4444-4444-4444-444444444444","pr":101}'
run --resume
check "merged-open: resumes the recorded session" '[ "$(calls_for ticket_12 | head -1 | cut -f2-3)" = "resume	44444444-4444-4444-4444-444444444444" ]' "$(cat "$FAKE_DIR/calls.log" 2>/dev/null)"
cleanup

echo "== resume: running ticket with no PR starts a fresh session"
setup
seed_state '{"status":"running","session":"33333333-3333-3333-3333-333333333333"}'
run --resume
check "no-pr: first call is a new session" '[ "$(calls_for ticket_12 | head -1 | cut -f2)" = new ]' "$(cat "$FAKE_DIR/calls.log" 2>/dev/null)"
check "no-pr: the old session id is not reused" '! grep -q 33333333 "$FAKE_DIR/calls.log"'
cleanup

echo "== halted run"
setup
seed_state '{"status":"needs_owner"}' '"ticket #12 needs the owner"'
run
check "halted: run without --resume refuses" '[ "$RC" = 1 ] && printf "%s" "$OUT" | grep -q "Use --resume"'
check "halted: nothing ran" '[ ! -s "$FAKE_DIR/calls.log" ]'
run --resume
check "halted: --resume clears the halt and retries the needs-owner ticket" '[ "$RC" = 0 ] && [ "$(state ".halted")" = null ] && grep -q "^ticket_12" "$FAKE_DIR/calls.log"' "$OUT"
cleanup

echo "== lock"
setup
sh -c 'exit 0' & dead=$!; wait "$dead"
mkdir -p "$STATE_DIR"; printf '%s\n' "$dead" > "$STATE_DIR/lock"
run
check "lock: a dead holder is reclaimed with a warning" '[ "$RC" = 0 ] && grep -q "reclaiming a stale lock from dead PID $dead" "$STATE_DIR/supervisor.log"' "$OUT"
check "lock: released at exit" '[ ! -f "$STATE_DIR/lock" ]'
check "state: valid JSON, no temp files left" 'jq -e . "$STATE_DIR/state.json" >/dev/null && ! ls "$STATE_DIR"/state.json.tmp.* >/dev/null 2>&1'
cleanup

echo "== status"
setup; seed_state '{"status":"running","pr":101}'
OUT="$("$UT_SUPERVISOR" status --prd "$PRD_FILE" --project widget --ops-root "$OPS_DIR" 2>&1)"
check "status: prints tickets and supervisor state" 'printf "%s" "$OUT" | grep -q "#12  running  PR #101" && printf "%s" "$OUT" | grep -q "Supervisor: not running"' "$OUT"
cleanup

ut_done
