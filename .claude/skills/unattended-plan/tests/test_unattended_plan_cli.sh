#!/bin/bash
# test_unattended_plan_cli.sh — the /unattended-plan entry script and the
# `bin/apexyard unattended-plan` arm (PRD-001 US-1, FR-1).
#
# Covers project resolution from the registry, the run token, --stop,
# --status, --dry-run, --rehearse without a terminal, the supervised-child
# refusal, the live-lock refusal, and a real detached (setsid) run.
#
# Exit 0 when every case passes.

# Variables such as RC, SIDE, and SHA_* are read inside eval'd check strings.
# shellcheck disable=SC2034
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
CLI="$HERE/../unattended-plan.sh"
UT_SUPERVISOR="$ROOT/bin/unattended-supervisor"
# shellcheck source=_lib-unattended-test.sh
. "$HERE/_lib-unattended-test.sh"
unset APEXYARD_UNATTENDED_SUPERVISED APEXYARD_APPROVAL_PROXY UNATTENDED_FOREGROUND
unset DISPLAY WAYLAND_DISPLAY
export FAKE_SCENARIO="$HERE/scenarios/happy.sh"
export CLAUDE_CODE_SESSION_ID=owner-cli-session

setup() {
  ut_sandbox
  set_issue 12 OPEN; set_issue 13 OPEN
  ut_sidecar '[{"n":12,"title":"Sign-up","blocked_by":[]},{"n":13,"title":"Availability","blocked_by":[12]}]'
  printf 'projects:\n  - name: widget\n    repo: acme/widget\n    docs: %s/docs\n    workspace: workspace/widget\n  - name: other\n    repo: acme/other\n' "$SB" > "$SB/registry.yaml"
  export UNATTENDED_OPS_ROOT="$OPS_DIR" UNATTENDED_REGISTRY="$SB/registry.yaml"
}
cli() { OUT="$(cd "$SB" && bash "$CLI" "$@" < /dev/null 2>&1)"; RC=$?; }
cleanup() { rm -rf "$SB"; }

echo "== refusals"
setup
OUT="$(APEXYARD_UNATTENDED_SUPERVISED=1 bash "$CLI" "$PRD_FILE" 2>&1)"; RC=$?
check "supervised child cannot start a run" '[ "$RC" = 2 ] && printf "%s" "$OUT" | grep -q "supervised child"' "$OUT"
check "no token written by the refused call" '[ ! -f "$STATE_DIR/run.token" ]'
printf '# other\n' > "$SB/elsewhere.md"
cli "$SB/elsewhere.md"
check "PRD outside every project asks for --project" '[ "$RC" = 2 ] && printf "%s" "$OUT" | grep -q -- "--project <name>"' "$OUT"
cli "$PRD_FILE" --project nope
check "unknown --project is refused" '[ "$RC" = 2 ] && printf "%s" "$OUT" | grep -q "no registered project named"' "$OUT"
cli
check "missing PRD path is a usage error" '[ "$RC" = 2 ]'
cleanup

echo "== dry-run"
setup; cli "$PRD_FILE" --dry-run
check "dry-run resolves the project and prints the plan" '[ "$RC" = 0 ] && printf "%s" "$OUT" | grep -q "Project:   widget (acme/widget)" && printf "%s" "$OUT" | grep -q "#12  Sign-up"' "$OUT"
check "dry-run writes no token" '[ ! -f "$STATE_DIR/run.token" ]'
cleanup

echo "== rehearse without a terminal"
setup; cli "$PRD_FILE" --rehearse
check "rehearse prints the terminal command" '[ "$RC" = 0 ] && printf "%s" "$OUT" | grep -q "bin/apexyard unattended-plan .* --rehearse"' "$OUT"
check "rehearse without a terminal writes no token" '[ ! -f "$STATE_DIR/run.token" ]'
cleanup

echo "== foreground run"
setup; UNATTENDED_FOREGROUND=1 cli "$PRD_FILE"
check "foreground run completes" '[ "$RC" = 0 ]' "$OUT"
check "token has run_id, prd, project, started_by" \
  'grep -q "^run_id=20" "$STATE_DIR/run.token" && grep -qx "prd=$PRD_FILE" "$STATE_DIR/run.token" && grep -qx "project=widget" "$STATE_DIR/run.token" && grep -qx "started_by=owner-cli-session" "$STATE_DIR/run.token"'
check "child sees the run id from the token" 'grep -q "run=$(sed -n "s/^run_id=//p" "$STATE_DIR/run.token")" "$FAKE_DIR/env.log"'
check "missing workspace is cloned before the first ticket" '[ "$(cat "$FAKE_DIR/cloned" 2>/dev/null)" = acme/widget ] && [ -d "$SB/workspace/widget/.git" ]'
check "children get --add-dir for the workspace, the portfolio root, and the PRD dir" \
  'grep "^ticket_12" "$FAKE_DIR/argv.log" | head -1 | grep -qF -- "--add-dir $SB/workspace/widget" &&
   grep "^ticket_12" "$FAKE_DIR/argv.log" | head -1 | grep -qF -- "--add-dir $SB " &&
   grep "^ticket_12" "$FAKE_DIR/argv.log" | head -1 | grep -qF -- "--add-dir $SB/docs"' "$(grep "^ticket_12" "$FAKE_DIR/argv.log" | head -1 | grep -o -- "--add-dir [^ ]*" | tr "\n" " ")"
cli "$PRD_FILE" --status
check "--status prints the run" '[ "$RC" = 0 ] && printf "%s" "$OUT" | grep -q "#13  done  PR #102"' "$OUT"
cli "$PRD_FILE" --stop
check "--stop removes the token and touches the stop file" '[ "$RC" = 0 ] && [ ! -f "$STATE_DIR/run.token" ] && [ -f "$STATE_DIR/stop" ]' "$OUT"
cleanup

echo "== live lock"
setup; mkdir -p "$STATE_DIR"; sleep 300 & holder=$!; printf '%s\n' "$holder" > "$STATE_DIR/lock"
cli "$PRD_FILE"
check "a second run on the same PRD is refused" '[ "$RC" = 3 ] && printf "%s" "$OUT" | grep -q "PID $holder"' "$OUT"
check "the refused run writes no token" '[ ! -f "$STATE_DIR/run.token" ]'
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
cleanup

echo "== detached run"
setup; cli "$PRD_FILE"
check "detached start prints PID and log" '[ "$RC" = 0 ] && printf "%s" "$OUT" | grep -q "PID:" && printf "%s" "$OUT" | grep -q "supervisor.log"' "$OUT"
for _ in $(seq 1 60); do
  [ -f "$STATE_DIR/summary.md" ] && [ ! -f "$STATE_DIR/lock" ] && break
  sleep 0.5
done
check "detached supervisor finished both tickets" '[ "$(jq -r "[.tickets[].status] | join(\",\")" "$STATE_DIR/state.json" 2>/dev/null)" = "done,done" ]' "$(cat "$STATE_DIR/console.log" 2>/dev/null | tail -5)"
check "console output captured" '[ -f "$STATE_DIR/console.log" ]'
cleanup

echo "== --tmux outside tmux"
setup; ( unset TMUX; UNATTENDED_FOREGROUND=1 cli "$PRD_FILE" --tmux )
OUT="$(cd "$SB" && env -u TMUX bash "$CLI" "$PRD_FILE" --tmux < /dev/null 2>&1)"; RC=$?
check "--tmux outside tmux says so and still starts" '[ "$RC" = 0 ] && printf "%s" "$OUT" | grep -q "not inside tmux"' "$OUT"
for _ in $(seq 1 60); do [ -f "$STATE_DIR/summary.md" ] && [ ! -f "$STATE_DIR/lock" ] && break; sleep 0.5; done
cleanup

echo "== bin/apexyard arm"
OUT="$(cd "$ROOT" && bin/apexyard unattended-plan 2>&1)"; RC=$?
check "bin/apexyard delegates to the entry script" '[ "$RC" = 2 ] && printf "%s" "$OUT" | grep -q "give the PRD path"' "$OUT"
OUT="$(cd "$ROOT" && bin/apexyard --help 2>&1)"
check "bin/apexyard help lists unattended-plan" 'printf "%s" "$OUT" | grep -q "unattended-plan <prd>"'

ut_done
