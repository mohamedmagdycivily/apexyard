#!/bin/bash
# test_proxy_line.sh — proxied approvals in /approve-merge and /approve-design
# (PRD-001 US-6, AgDR-0222).
#
# Cases:
#   1. No APEXYARD_APPROVAL_PROXY: the check passes, no proxy= line, no prefix.
#   2. Proxy set + matching run token: check passes, proxy= line, prefix.
#   3. Proxy set + no token: refused.
#   4. Proxy set + a token for another run: refused.
#   5. The proxy value is sanitised (no quotes, backticks, dollars).
#   6. A CEO marker written the way SKILL.md step 5 writes it keeps
#      approved_by=user and gains exactly one proxy= line.
#   7. block-unreviewed-merge.sh accepts a CEO marker carrying the proxy= line.
#   8. SKILL.md wiring: /approve-merge calls the check and the marker-line
#      helper, /approve-design calls the check and leaves its bare-SHA marker.
#
# Exit 0 when every case passes.

# RC, AM, and AD are read inside eval'd check strings.
# shellcheck disable=SC2034
set -u
SRC_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
LIB="$SRC_ROOT/.claude/skills/unattended-plan/_lib-unattended-proxy.sh"
# shellcheck source=../../unattended-plan/_lib-unattended-proxy.sh
. "$LIB"

PASS=0 FAIL=0
check() { if eval "$2"; then PASS=$((PASS + 1)); echo "PASS: $1"; else FAIL=$((FAIL + 1)); echo "FAIL: $1"; [ -n "${3:-}" ] && printf '      %s\n' "$3"; fi; }

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
OPS="$SB/ops"
mkdir -p "$OPS/.claude/session/unattended/widget-prd-001" "$OPS/.claude/session/reviews"
TOKEN="$OPS/.claude/session/unattended/widget-prd-001/run.token"
PROXY='unattended-plan run=run-42 prd=/x/PRD-001.md ticket=12 started_by=owner-session'

# 1 ---------------------------------------------------------------------
unset APEXYARD_APPROVAL_PROXY
check "no proxy: check passes" 'unattended_proxy_check "$OPS"'
check "no proxy: no marker line" '[ -z "$(unattended_proxy_marker_line)" ]'
check "no proxy: no summary prefix" '[ -z "$(unattended_proxy_summary_prefix)" ]'

# 2 ---------------------------------------------------------------------
export APEXYARD_APPROVAL_PROXY="$PROXY"
printf 'run_id=run-42\nprd=/x/PRD-001.md\nproject=widget\nstarted_by=owner-session\n' > "$TOKEN"
check "proxy + token: check passes" 'unattended_proxy_check "$OPS"'
check "proxy + token: marker line" '[ "$(unattended_proxy_marker_line)" = "proxy=\"$PROXY\"" ]'
check "proxy + token: summary prefix" '[ "$(unattended_proxy_summary_prefix)" = "[proxy: run=run-42 ticket=12] " ]'

# 3 ---------------------------------------------------------------------
rm -f "$TOKEN"
ERR="$(unattended_proxy_check "$OPS" 2>&1)"; RC=$?
check "proxy, no token: refused" '[ "$RC" = 1 ] && printf "%s" "$ERR" | grep -q "no run token for Unattended Mode run .run-42."' "$ERR"

# 4 ---------------------------------------------------------------------
printf 'run_id=run-OTHER\n' > "$TOKEN"
unattended_proxy_check "$OPS" 2>/dev/null; RC=$?
check "proxy, token of another run: refused" '[ "$RC" = 1 ]'
APEXYARD_APPROVAL_PROXY="unattended-plan prd=/x" unattended_proxy_check "$OPS" 2>/dev/null; RC=$?
check "proxy without run id: refused" '[ "$RC" = 1 ]'

# 5 ---------------------------------------------------------------------
APEXYARD_APPROVAL_PROXY='unattended-plan run=r1 prd="/x/$(id)`y`\z" ticket=1'
check "sanitised: no quote, backtick, dollar, backslash inside the value" \
  '[ "$(unattended_proxy_marker_line)" = "proxy=\"unattended-plan run=r1 prd=/x/(id)yz ticket=1\"" ]'
export APEXYARD_APPROVAL_PROXY="$PROXY"

# 6 ---------------------------------------------------------------------
# Mirror SKILL.md step 5: heredoc first, then the proxy line appended.
printf 'run_id=run-42\n' > "$TOKEN"
CEO="$OPS/.claude/session/reviews/acme__widget__7-ceo.approved"
SHA=abcdef1234567890abcdef1234567890abcdef12
summary="$(unattended_proxy_summary_prefix)$(echo "/approve-merge acme/widget#7" | tr '\n' ' ' | tr -d '"`$\\')"
summary="$(printf '%s' "$summary" | cut -c1-200)"
cat > "$CEO" <<EOF
sha=${SHA}
approved_by=user
approved_at=2026-10-08T00:00:00Z
skill_version=2
approval_summary="${summary}"
EOF
unattended_proxy_marker_line >> "$CEO"
check "marker: approved_by=user unchanged" 'grep -qx "approved_by=user" "$CEO"'
check "marker: exactly one proxy= line" '[ "$(grep -c "^proxy=" "$CEO")" = 1 ]'
check "marker: summary carries the proxy prefix" 'grep -qx "approval_summary=\"\[proxy: run=run-42 ticket=12\] /approve-merge acme/widget#7 \"" "$CEO"' "$(cat "$CEO")"

# 7 ---------------------------------------------------------------------
GATE="$SB/gate"
mkdir -p "$GATE/.claude/hooks" "$GATE/.claude/session/reviews" "$GATE/bin"
( cd "$GATE" && git init -q && git config user.email t@e && git config user.name t && : > onboarding.yaml && git add onboarding.yaml && git commit -q -m init )
for f in block-unreviewed-merge.sh _lib-extract-pr.sh _lib-review-markers.sh _lib-merge-behind.sh _lib-read-config.sh; do
  [ -f "$SRC_ROOT/.claude/hooks/$f" ] && cp "$SRC_ROOT/.claude/hooks/$f" "$GATE/.claude/hooks/$f"
done
cp "$SRC_ROOT/.claude/project-config.defaults.json" "$GATE/.claude/project-config.defaults.json"
cat > "$GATE/bin/gh" <<EOF
#!/bin/bash
case "\$*" in
  *"pr view"*"headRefOid"*)       echo "$SHA" ;;
  *"pr view"*"headRefName"*)      echo "feature/GH-7-x" ;;
  *"pr view"*"headRepository"*)   echo "acme/widget" ;;
  *"pr view"*"mergeStateStatus"*) echo "CLEAN" ;;
  *"pr view"*"baseRefName"*)      echo "main" ;;
  *"api "*"compare/"*)            echo "0" ;;
esac
exit 0
EOF
chmod +x "$GATE/bin/gh"
echo "$SHA" > "$GATE/.claude/session/reviews/acme__widget__7-rex.approved"
cp "$CEO" "$GATE/.claude/session/reviews/acme__widget__7-ceo.approved"
gate_rc() {
  local input
  input=$(jq -nc --arg c "gh pr merge 7 --repo acme/widget --squash" '{tool_name:"Bash", tool_input:{command:$c}}')
  ( cd "$GATE" && printf '%s' "$input" | APEXYARD_OPS_DISABLE_PIN=1 PATH="$GATE/bin:$PATH" bash .claude/hooks/block-unreviewed-merge.sh >/dev/null 2>"$SB/gate.err" )
}
gate_rc; RC=$?
check "gate: accepts a CEO marker with a proxy= line" '[ "$RC" = 0 ]' "$(cat "$SB/gate.err")"
sed -i 's/^approved_by=user$/approved_by=proxy/' "$GATE/.claude/session/reviews/acme__widget__7-ceo.approved"
gate_rc; RC=$?
check "gate: still rejects approved_by other than user (control)" '[ "$RC" = 2 ]'

# 8 ---------------------------------------------------------------------
AM="$SRC_ROOT/.claude/skills/approve-merge/SKILL.md"
AD="$SRC_ROOT/.claude/skills/approve-design/SKILL.md"
check "approve-merge: calls unattended_proxy_check" 'grep -q "unattended_proxy_check \"\$MARKER_HOME\"" "$AM"'
check "approve-merge: appends the proxy line to the CEO marker" 'grep -q "unattended_proxy_marker_line >> \"\$CEO\"" "$AM"'
check "approve-merge: step 5 sources the helper itself" 'sed -n "/^### 5. Write the structured CEO marker/,/^### 6/p" "$AM" | grep -q "_lib-unattended-proxy.sh"'
check "approve-merge: prefixes approval_summary" 'grep -q "unattended_proxy_summary_prefix" "$AM"'
check "approve-design: calls unattended_proxy_check" 'grep -q "unattended_proxy_check \"\$MARKER_HOME\"" "$AD"'
check "approve-design: never writes a proxy line" '! grep -q "unattended_proxy_marker_line" "$AD"'

echo
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" = 0 ]
