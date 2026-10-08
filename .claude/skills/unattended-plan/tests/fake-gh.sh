#!/bin/bash
# fake-gh.sh — stand-in for gh in the Unattended Mode tests. Reads the fake
# tracker under $FAKE_DIR (issues/<n>.json, prs/<p>.json, checks/<p>.json).
set -u
printf '%s\n' "$*" >> "$FAKE_DIR/gh.log"
sub="${1:-} ${2:-}"
num="${3:-}"
case "$sub" in
  "issue view")
    f="$FAKE_DIR/issues/$num.json"
    [ -f "$f" ] || { echo "GraphQL: Could not resolve to an issue with the number of $num." >&2; exit 1; }
    cat "$f" ;;
  "pr view")
    f="$FAKE_DIR/prs/$num.json"
    [ -f "$f" ] || { echo "no pull requests found" >&2; exit 1; }
    cat "$f" ;;
  "pr checks")
    f="$FAKE_DIR/checks/$num.json"
    if [ -f "$f" ]; then cat "$f"; grep -q '"fail"' "$f" && exit 1; else echo '[]'; fi ;;
  "pr list")
    if ls "$FAKE_DIR"/prs/*.json >/dev/null 2>&1; then jq -s '.' "$FAKE_DIR"/prs/*.json; else echo '[]'; fi ;;
  "repo view")
    # --json defaultBranchRef --jq .defaultBranchRef.name
    echo "${FAKE_DEFAULT_BRANCH:-main}" ;;
  "repo clone")
    # gh repo clone <repo> <dir>: make an empty git clone stand-in.
    [ "${FAKE_CLONE_FAIL:-0}" = 1 ] && exit 1
    mkdir -p "$4" && git -C "$4" init -q && echo "$3" > "$FAKE_DIR/cloned" ;;
  *)
    case "$*" in
      "api repos/"*"/branches"*) echo "${FAKE_BRANCHES:-1}" ;;
    esac
    exit 0 ;;
esac
