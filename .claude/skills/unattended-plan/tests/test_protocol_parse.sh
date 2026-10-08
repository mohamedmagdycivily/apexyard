#!/bin/bash
# test_protocol_parse.sh — table-driven tests for _lib-unattended-protocol.sh,
# the end-line parser bin/unattended-supervisor uses (PRD-001 FR-8).
#
# Exit 0 when every case passes.

# Variables such as RC, SIDE, and SHA_* are read inside eval'd check strings.
# shellcheck disable=SC2034
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../_lib-unattended-protocol.sh
. "$HERE/../_lib-unattended-protocol.sh"

PASS=0 FAIL=0
T=$'\t'
expect() { # <name> <got> <want>
  if [ "$2" = "$3" ]; then PASS=$((PASS + 1)); echo "PASS: $1"
  else FAIL=$((FAIL + 1)); echo "FAIL: $1"; printf '      got:  %q\n      want: %q\n' "$2" "$3"; fi
}

# ---- up_parse: one row per protocol line --------------------------------
while IFS='|' read -r name line want; do
  [ -z "$name" ] && continue
  want="${want//<T>/$T}"
  expect "parse: $name" "$(up_parse "$line")" "$want"
done <<'ROWS'
tickets|UNATTENDED-TICKETS: epic=11 tickets=12,13,14|tickets<T>11<T>12,13,14
tickets with hashes|UNATTENDED-TICKETS: epic=#11 tickets=#12,#13|tickets<T>11<T>12,13
tickets no epic|UNATTENDED-TICKETS: tickets=12|tickets<T><T>12
tickets bad list|UNATTENDED-TICKETS: epic=11 tickets=twelve|invalid<T>UNATTENDED-TICKETS: epic=11 tickets=twelve
approve merge|UNATTENDED-APPROVE: merge pr=101|approve<T>merge<T>101
approve design|UNATTENDED-APPROVE: design pr=#7|approve<T>design<T>7
approve unknown kind|UNATTENDED-APPROVE: deploy pr=7|invalid<T>UNATTENDED-APPROVE: deploy pr=7
approve no pr|UNATTENDED-APPROVE: merge|invalid<T>UNATTENDED-APPROVE: merge
next|UNATTENDED-NEXT: ticket=12 done pr=101|next<T>12<T>101
next missing pr|UNATTENDED-NEXT: ticket=12 done|invalid<T>UNATTENDED-NEXT: ticket=12 done
done|UNATTENDED-DONE|done
done with colon|UNATTENDED-DONE: all tickets merged|done
blocked|UNATTENDED-BLOCKED: credentials the API key is missing|blocked<T>credentials<T>the API key is missing
blocked code only|UNATTENDED-BLOCKED: device|blocked<T>device<T>
blocked unknown code|UNATTENDED-BLOCKED: tired need a break|invalid<T>UNATTENDED-BLOCKED: tired need a break
decorated line|  > **`UNATTENDED-APPROVE: merge pr=5`**  |approve<T>merge<T>5
not a protocol line|Please merge PR 5|invalid<T>Please merge PR 5
ROWS

# ---- ASK with and without a recommendation ------------------------------
expect "parse: ask with recommendation" \
  "$(up_parse 'UNATTENDED-ASK: Which picker? | options: A; B | recommended: B')" \
  "ask${T}Which picker?${T}A; B${T}B"
expect "parse: ask without recommendation" \
  "$(up_parse 'UNATTENDED-ASK: What should the button say?')" \
  "ask${T}What should the button say?${T}${T}"
expect "parse: ask recommendation before options" \
  "$(up_parse 'UNATTENDED-ASK: Q? | recommended: yes | options: yes; no')" \
  "ask${T}Q?${T}yes; no${T}yes"
expect "parse: empty ask is invalid" "$(up_parse 'UNATTENDED-ASK:')" "invalid${T}UNATTENDED-ASK:"

# ---- up_end_line + up_is_last_line --------------------------------------
TEXT="Built the feature.
UNATTENDED-STATUS: rex=approved round=1 ci=green
UNATTENDED-APPROVE: merge pr=101"
expect "end-line: last protocol line, STATUS ignored" "$(up_end_line "$TEXT")" "UNATTENDED-APPROVE: merge pr=101"
up_is_last_line "$TEXT"; expect "end-line: is last" "$?" 0

TWO="UNATTENDED-ASK: Q? | options: a; b | recommended: a
More thinking.
UNATTENDED-APPROVE: design pr=3"
expect "end-line: two lines, the last one wins" "$(up_end_line "$TWO")" "UNATTENDED-APPROVE: design pr=3"

TRAIL="UNATTENDED-APPROVE: merge pr=101
Let me know if you need anything."
expect "end-line: found even when not last" "$(up_end_line "$TRAIL")" "UNATTENDED-APPROVE: merge pr=101"
up_is_last_line "$TRAIL"; expect "end-line: not last is detected" "$?" 1

TRAILBLANK=$'UNATTENDED-DONE\n\n   \n'
up_is_last_line "$TRAILBLANK"; expect "end-line: trailing blank lines are fine" "$?" 0

CRLF=$'Done.\r\nUNATTENDED-DONE\r'
expect "end-line: CRLF stripped" "$(up_end_line "$CRLF")" "UNATTENDED-DONE"

STATUS_LAST="UNATTENDED-APPROVE: merge pr=1
UNATTENDED-STATUS: rex=approved round=1 ci=green"
up_is_last_line "$STATUS_LAST"; expect "end-line: STATUS as last line is not an end line" "$?" 1

expect "end-line: none" "$(up_end_line "no protocol here")" ""

# ---- up_status ------------------------------------------------------------
expect "status: fields" "$(up_status "$TEXT")" "approved${T}1${T}green"
up_status "nothing" >/dev/null; expect "status: absent returns 1" "$?" 1

# ---- blocked codes ----------------------------------------------------------
for c in credentials account device privileged ambiguous-scope external-dependency; do
  up_blocked_code_valid "$c"; expect "code: $c is valid" "$?" 0
done
up_blocked_code_valid "nope"; expect "code: unknown is invalid" "$?" 1

echo
echo "Passed: $PASS  Failed: $FAIL"
[ "$FAIL" = 0 ]
