#!/bin/bash
# _lib-unattended-test.sh — shared sandbox + fake-tracker helpers for the
# Unattended Mode tests. Sourced by the test files and by fake-claude.sh.
#
# Layout of a sandbox ($SB):
#   $SB/ops/                 the ops root the supervisor uses (--ops-root)
#   $SB/docs/PRD-001-x.md    the PRD
#   $SB/fake/                the fake tracker ($FAKE_DIR)
#   $SB/bin/gh, claude       the fakes, first on PATH

# SHA_* are read by the scenario files and eval'd checks.
# shellcheck disable=SC2034
UT_REPO="acme/widget"

ut_sandbox() { # → sets SB, FAKE_DIR, OPS_DIR, PRD_FILE, STATE_DIR; exports PATH
  SB="$(mktemp -d)"
  FAKE_DIR="$SB/fake"; OPS_DIR="$SB/ops"; PRD_FILE="$SB/docs/PRD-001-x.md"
  mkdir -p "$FAKE_DIR/issues" "$FAKE_DIR/prs" "$FAKE_DIR/checks" "$OPS_DIR/.claude/session/reviews" "$SB/docs" "$SB/bin"
  printf '# PRD-001 X\n' > "$PRD_FILE"
  local here; here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cp "$here/fake-gh.sh" "$SB/bin/gh"; chmod +x "$SB/bin/gh"
  export FAKE_DIR OPS_DIR
  export PATH="$SB/bin:$PATH"
  export UNATTENDED_CLAUDE_BIN="$here/fake-claude.sh"
  STATE_DIR="$OPS_DIR/.claude/session/unattended/widget-prd-001-x"
  export STATE_DIR
}

ut_token() { # write a run token like /unattended-plan does
  mkdir -p "$STATE_DIR"
  printf 'run_id=test-run\nprd=%s\nproject=widget\nstarted_by=owner-session\nstarted_at=2026-10-08T00:00:00Z\n' "$PRD_FILE" > "$STATE_DIR/run.token"
}

ut_sidecar() { # <json tickets array> [epic]
  jq -n --argjson t "$1" --argjson e "${2:-11}" \
    '{config:{execution_prompt:"", max_turn_usd:15, max_ticket_usd:60, max_run_usd:300, turn_timeout_s:60, notify_webhook:""}, epic:$e, tickets:$t}' \
    > "$SB/docs/PRD-001-x.unattended.json"
}

ut_supervisor() { # run the supervisor against the sandbox; extra args pass through
  "$UT_SUPERVISOR" run --prd "$PRD_FILE" --project widget --repo "$UT_REPO" --ops-root "$OPS_DIR" "$@"
}

# ---- fake tracker helpers (also used inside scenario turn functions) ----

set_issue() { # <n> <OPEN|CLOSED> [title] [body] [labels csv]
  local labels="[]"
  [ -n "${5:-}" ] && labels="$(printf '%s' "$5" | jq -R 'split(",") | map({name: .})')"
  jq -n --argjson n "$1" --arg s "$2" --arg t "${3:-[Feature] Ticket $1}" --arg b "${4:-}" --argjson l "$labels" \
    '{number:$n, state:$s, title:$t, body:$b, labels:$l, url:"https://github.com/acme/widget/issues/\($n)"}' \
    > "$FAKE_DIR/issues/$1.json"
}

issue_state() { jq -r .state "$FAKE_DIR/issues/$1.json"; }

# The default branch maps PR 101 → ticket 12, 102 → 13 (PR - 89), the pairing
# every scenario uses, so verify_done's branch check sees the right ticket.
set_pr() { # <p> <OPEN|MERGED|CLOSED> <head sha> [branch] [draft]
  jq -n --argjson p "$1" --arg s "$2" --arg h "$3" --arg b "${4:-feature/GH-$(( $1 - 89 ))-x}" --argjson d "${5:-false}" \
    '{number:$p, state:$s, isDraft:$d, headRefOid:$h, headRefName:$b, url:"https://github.com/acme/widget/pull/\($p)"}' \
    > "$FAKE_DIR/prs/$1.json"
}

pr_state_of() { jq -r .state "$FAKE_DIR/prs/$1.json"; }

pr_head() { jq -r .headRefOid "$FAKE_DIR/prs/$1.json"; }

rex_ok() { # <p> — Rex approved the PR's current head: marker + posted review
  local h; h="$(pr_head "$1")"
  printf '%s\n' "$h" > "$OPS_DIR/.claude/session/reviews/acme__widget__$1-rex.approved"
  jq --arg h "$h" '.reviews = ((.reviews // []) + [{body: ("Verdict: APPROVED\n\nReviewed commit: " + $h)}])' \
    "$FAKE_DIR/prs/$1.json" > "$FAKE_DIR/prs/$1.json.tmp" && mv "$FAKE_DIR/prs/$1.json.tmp" "$FAKE_DIR/prs/$1.json"
}

rex_marker_only() { # <p> — a marker file with no posted review (forged)
  printf '%s\n' "$(pr_head "$1")" > "$OPS_DIR/.claude/session/reviews/acme__widget__$1-rex.approved"
}

ci() { # <p> <pass|fail>
  jq -n --arg b "$2" '[{name:"tests", bucket:$b}]' > "$FAKE_DIR/checks/$1.json"
}

fake_snapshot() {
  local f
  for f in "$FAKE_DIR"/issues/*.json "$FAKE_DIR"/prs/*.json; do
    [ -f "$f" ] && jq -r '"\(if .headRefOid then "pr" else "issue" end) \(.number) \(.state)"' "$f"
  done
}

SHA_A=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
SHA_B=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
SHA_C=cccccccccccccccccccccccccccccccccccccccc

# ---- assertions ----

PASS=${PASS:-0}; FAIL=${FAIL:-0}
ok()   { PASS=$((PASS + 1)); echo "PASS: $1"; }
bad()  { FAIL=$((FAIL + 1)); echo "FAIL: $1"; [ -n "${2:-}" ] && printf '      %s\n' "$2"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }
calls_for() { awk -F'\t' -v k="$1" '$1 == k' "$FAKE_DIR/calls.log" 2>/dev/null; }
ut_done() { echo; echo "Passed: $PASS  Failed: $FAIL"; [ "$FAIL" = 0 ]; }
