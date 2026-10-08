#!/bin/bash
# unattended-plan.sh — entry point of the human-only /unattended-plan skill
# and of `bin/apexyard unattended-plan` (AgDR-0222).
#
# Invoking it is the owner's delegation of approval for ONE run: it writes the
# run token that the supervisor and the approve skills check, then starts
# bin/unattended-supervisor detached with setsid so the owner can close the
# session.
#
# Usage:
#   unattended-plan.sh <prd-path> [--project <name>] [--plan-only]
#                      [--tickets 12,14] [--rehearse] [--dry-run]
#                      [--resume] [--stop] [--status]
#
# Test seams: UNATTENDED_OPS_ROOT (ops root), UNATTENDED_REGISTRY (registry
# file), UNATTENDED_FOREGROUND=1 (run the supervisor in the foreground).

set -u

if [ "${APEXYARD_UNATTENDED_SUPERVISED:-}" = 1 ]; then
  echo "unattended-plan: refusing to run inside a supervised child session (APEXYARD_UNATTENDED_SUPERVISED=1)." >&2
  echo "Only the owner can start an Unattended Mode run." >&2
  exit 2
fi

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPS="${UNATTENDED_OPS_ROOT:-$(cd "$SELF_DIR/../../.." && pwd)}"
SUPERVISOR="$(cd "$SELF_DIR/../../.." && pwd)/bin/unattended-supervisor"

PRD="" PROJECT="" ACTION=run PASS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT="${2:-}"; shift 2 ;;
    --tickets) PASS+=(--tickets "${2:-}"); shift 2 ;;
    --plan-only|--resume) PASS+=("$1"); shift ;;
    --rehearse) ACTION=rehearse; shift ;;
    --dry-run) ACTION=dry-run; shift ;;
    --stop) ACTION=stop; shift ;;
    --status) ACTION=status; shift ;;
    -h|--help) sed -n '10,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unattended-plan: unknown flag: $1" >&2; exit 2 ;;
    *) if [ -z "$PRD" ]; then PRD="$1"; shift; else echo "unattended-plan: one PRD path only" >&2; exit 2; fi ;;
  esac
done

[ -n "$PRD" ] || { echo "unattended-plan: give the PRD path: /unattended-plan <prd-file>" >&2; exit 2; }
[ -f "$PRD" ] || { echo "unattended-plan: PRD not found: $PRD" >&2; exit 2; }
PRD="$(cd "$(dirname "$PRD")" && pwd)/$(basename "$PRD")"

# ---------------------------------------------------------- resolve project --

REGISTRY="${UNATTENDED_REGISTRY:-}"
if [ -z "$REGISTRY" ]; then
  # shellcheck source=/dev/null
  . "$OPS/.claude/hooks/_lib-portfolio-paths.sh" 2>/dev/null && REGISTRY="$(cd "$OPS" && portfolio_registry)"
fi
[ -f "$REGISTRY" ] || { echo "unattended-plan: registry not found (${REGISTRY:-unset})" >&2; exit 2; }

# Print "name<TAB>repo<TAB>workspace" for the project that owns the PRD:
# the --project entry, or the entry whose docs / workspace / projects/<name>
# directory contains the PRD. Relative paths resolve against the registry's
# directory, then the ops root.
resolved="$(python3 - "$REGISTRY" "$OPS" "$PRD" "$PROJECT" <<'PY'
import os, sys
try:
    import yaml
except ImportError:
    sys.exit("PyYAML is not installed")
reg, ops, prd, want = sys.argv[1:5]
data = yaml.safe_load(open(reg)) or {}
base = os.path.dirname(os.path.abspath(reg))
def resolve(p):
    if not p:
        return ""
    if os.path.isabs(p):
        return os.path.realpath(p)
    for root in (base, ops):
        cand = os.path.realpath(os.path.join(root, p))
        if os.path.exists(cand):
            return cand
    return os.path.realpath(os.path.join(base, p))
prd = os.path.realpath(prd)
hits = []
for e in data.get("projects", []) or []:
    name = str(e.get("name", ""))
    if want:
        if name == want:
            hits = [e]; break
        continue
    roots = [resolve(e.get("docs", "")), resolve(e.get("workspace", "")),
             resolve(os.path.join("projects", name))]
    if any(r and (prd == r or prd.startswith(r.rstrip("/") + "/")) for r in roots):
        hits.append(e)
if len(hits) != 1:
    sys.exit(2 if not hits else 3)
e = hits[0]
print("\t".join([str(e.get("name", "")), str(e.get("repo", "")), resolve(e.get("workspace", ""))]))
PY
)"
rc=$?
if [ "$rc" != 0 ] || [ -z "$resolved" ]; then
  if [ -n "$PROJECT" ]; then echo "unattended-plan: no registered project named '$PROJECT'." >&2
  else echo "unattended-plan: the PRD path is not under exactly one registered project. Pass --project <name>." >&2; fi
  exit 2
fi
PROJECT="$(printf '%s' "$resolved" | cut -f1)"
REPO="$(printf '%s' "$resolved" | cut -f2)"
WORKSPACE="$(printf '%s' "$resolved" | cut -f3)"
[ -n "$REPO" ] || { echo "unattended-plan: project '$PROJECT' has no repo in the registry." >&2; exit 2; }

paths="$("$SUPERVISOR" paths --prd "$PRD" --project "$PROJECT" --ops-root "$OPS")"
STATE_DIR="$(printf '%s\n' "$paths" | sed -n 's/^state_dir=//p')"
SIDECAR="$(printf '%s\n' "$paths" | sed -n 's/^sidecar=//p')"
TOKEN="$STATE_DIR/run.token"
LOCK="$STATE_DIR/lock"
SV_ARGS=(--prd "$PRD" --project "$PROJECT" --repo "$REPO" --ops-root "$OPS")
[ -n "$WORKSPACE" ] && SV_ARGS+=(--workspace "$WORKSPACE")

live_pid() { local p; p="$(cat "$LOCK" 2>/dev/null)"; [ -n "$p" ] && kill -0 "$p" 2>/dev/null && printf '%s' "$p"; }

case "$ACTION" in
  status)
    exec "$SUPERVISOR" status --prd "$PRD" --project "$PROJECT" --ops-root "$OPS" ;;
  stop)
    mkdir -p "$STATE_DIR"
    rm -f "$TOKEN"
    : > "$STATE_DIR/stop"
    echo "Stop requested for $PROJECT / $(basename "$PRD")."
    echo "The run token is removed. The supervisor finishes its current turn, sends nothing more, and writes $STATE_DIR/summary.md."
    exit 0 ;;
  dry-run)
    exec "$SUPERVISOR" run "${SV_ARGS[@]}" --dry-run "${PASS[@]}" ;;
esac

# ------------------------------------------------------------ start a run --

if pid="$(live_pid)"; then
  echo "unattended-plan: a supervisor (PID $pid) is already running this PRD. Use --status or --stop." >&2
  exit 3
fi

if [ "$ACTION" = rehearse ] && [ "${UNATTENDED_FOREGROUND:-}" != 1 ] && ! { [ -t 0 ] && [ -r /dev/tty ]; }; then
  echo "A rehearsal pauses for a keypress before each approval, so it needs a terminal."
  echo "Run this in a separate terminal and watch ticket 1 through its first approval:"
  echo
  echo "  $OPS/bin/apexyard unattended-plan '$PRD' --rehearse${PROJECT:+ --project $PROJECT}"
  exit 0
fi

mkdir -p "$STATE_DIR"
run_id="$(date -u +%Y%m%dT%H%M%SZ)-$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')"
started_by="${CLAUDE_CODE_SESSION_ID:-$(tty 2>/dev/null | grep -v 'not a tty' || echo "${USER:-unknown}@$(hostname 2>/dev/null)")}"
tmp="$TOKEN.tmp.$$"
{
  printf 'run_id=%s\n' "$run_id"
  printf 'prd=%s\n' "$PRD"
  printf 'project=%s\n' "$PROJECT"
  printf 'started_by=%s\n' "$started_by"
  printf 'started_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$tmp" && mv "$tmp" "$TOKEN"
rm -f "$STATE_DIR/stop"

[ "$ACTION" = rehearse ] && PASS+=(--rehearse)

if [ "$ACTION" = rehearse ] || [ "${UNATTENDED_FOREGROUND:-}" = 1 ]; then
  echo "Run $run_id (foreground). Log: $STATE_DIR/supervisor.log"
  exec "$SUPERVISOR" run "${SV_ARGS[@]}" "${PASS[@]}"
fi

command -v setsid >/dev/null 2>&1 || { echo "unattended-plan: setsid is required to detach the supervisor" >&2; exit 2; }
setsid -f "$SUPERVISOR" run "${SV_ARGS[@]}" "${PASS[@]}" >> "$STATE_DIR/console.log" 2>&1 < /dev/null

pid=""
for _ in 1 2 3 4 5 6 7 8 9 10; do pid="$(live_pid)" && break; sleep 0.5; done
echo "Unattended Mode run started."
echo "  Run:      $run_id"
echo "  Project:  $PROJECT ($REPO)"
echo "  PRD:      $PRD"
echo "  Sidecar:  $SIDECAR$([ -f "$SIDECAR" ] && echo ' (exists, it wins)' || echo ' (the planning session writes it)')"
echo "  PID:      ${pid:-not yet visible, check the log}"
echo "  Log:      $STATE_DIR/supervisor.log"
echo
echo "Watch:  tail -f '$STATE_DIR/supervisor.log'"
echo "Status: /unattended-plan '$PRD' --status"
echo "Stop:   /unattended-plan '$PRD' --stop"
echo "You can close this session now."
