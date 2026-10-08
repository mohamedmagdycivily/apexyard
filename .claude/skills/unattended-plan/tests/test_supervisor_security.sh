#!/bin/bash
# test_supervisor_security.sh — regression scenarios for the security reviews
# of PRs #7 and #9, driven end to end against fake-claude.sh and fake-gh.sh
# (AgDR-0222).
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

# ---------------------------------------------------- security regressions --
echo "== sec: slash reply"
ut_sandbox; two_tickets '[]'; run_scenario sec-slash-reply --tickets 12
P2="$FAKE_DIR/prompt.ticket_12.2"
check "sec-slash: the reply is not sent as a slash command" '[ "$(head -c1 "$P2")" != "/" ] && grep -q "plain text" "$P2"' "$(cat "$P2")"
check "sec-slash: no approval recorded" '[ ! -s "$STATE_DIR/approvals.jsonl" ]'
check "sec-slash: refusal logged" 'grep -q "refused to send a slash command the supervisor did not build" "$STATE_DIR/supervisor.log"'
cleanup

echo "== sec: other ticket's PR"
ut_sandbox; two_tickets '[]'; run_scenario sec-other-pr --tickets 12
check "sec-other-pr: PR on another ticket's branch refused" 'grep -q "is not the PR for ticket #12" "$FAKE_DIR/prompt.ticket_12.2"'
check "sec-other-pr: own PR approved" '[ "$(cat "$FAKE_DIR/prompt.ticket_12.3")" = "/approve-design acme/widget#101" ]'
check "sec-other-pr: second PR for the same ticket refused" 'grep -q "already has PR #101" "$FAKE_DIR/prompt.ticket_12.4"'
check "sec-other-pr: only the own PR reached approvals.jsonl" '[ "$(jq -r .pr "$STATE_DIR/approvals.jsonl" | sort -u | tr "\n" " ")" = "101 " ]'
cleanup

echo "== sec: forged marker"
ut_sandbox; two_tickets '[]'; run_scenario sec-forged-marker --tickets 12
check "sec-forged: marker without a posted review is refused" 'grep -q "No posted Rex review on PR #101" "$FAKE_DIR/prompt.ticket_12.2"'
check "sec-forged: approval after the posted review" '[ "$(cat "$FAKE_DIR/prompt.ticket_12.3")" = "/approve-merge acme/widget#101" ] && [ "$RC" = 0 ]' "$OUT"
cleanup

echo "== sec: token rewritten"
ut_sandbox; two_tickets '[]'; : > "$STATE_DIR/stop.ignored"; run_scenario sec-token-rewritten --tickets 12
check "sec-token: a rewritten token halts the run" '[ "$RC" = 1 ] && state ".halted" | grep -q "run token removed or changed" && [ "$(calls_for ticket_12 | wc -l)" = 1 ]' "$OUT"
cleanup

echo "== sec: sidecar edited"
ut_sandbox; two_tickets '[]'; export SIDECAR_FILE="$SB/docs/PRD-001-x.unattended.json"; run_scenario sec-sidecar-edit --tickets 12
check "sec-sidecar: an edit during the run halts it" '[ "$RC" = 1 ] && state ".halted" | grep -q "sidecar changed"' "$OUT"
cleanup

echo "== sec: log forging + permissions"
ut_sandbox; two_tickets '[]'; run_scenario sec-log-forge --tickets 12
check "sec-log: no forged START line" '! grep -q "^2026-01-01T00:00:00Z START run=forged" "$STATE_DIR/supervisor.log"'
check "sec-perms: state.json is private (600)" '[ "$(stat -c %a "$STATE_DIR/state.json")" = 600 ]'
check "sec-perms: turn logs are private" '[ "$(stat -c %a "$STATE_DIR/logs/ticket-12/turn-1.jsonl")" = 600 ]'
cleanup

echo "== sec: unicode slash"
ut_sandbox; two_tickets '[]'; run_scenario sec-unicode-slash --tickets 12
check "sec-unicode: a slash behind U+00A0 is sent as plain text" 'grep -q "plain text" "$FAKE_DIR/prompt.ticket_12.2"' "$(cat "$FAKE_DIR/prompt.ticket_12.2")"
cleanup

echo "== sec: fork PR"
ut_sandbox; two_tickets '[]'; run_scenario sec-fork-pr --tickets 12
check "sec-fork: a PR from another repository is refused" 'grep -q "comes from evil/widget, not acme/widget" "$FAKE_DIR/prompt.ticket_12.2" && [ ! -s "$STATE_DIR/approvals.jsonl" ]'
cleanup

echo "== sec: footer in a comment"
ut_sandbox; two_tickets '[]'; run_scenario sec-comment-review --tickets 12
check "sec-comment: a Rex footer in an issue comment is not a review" 'grep -q "No posted Rex review" "$FAKE_DIR/prompt.ticket_12.2"'
cleanup

ut_done
