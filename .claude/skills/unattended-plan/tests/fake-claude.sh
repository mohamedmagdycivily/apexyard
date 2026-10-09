#!/bin/bash
# fake-claude.sh — stand-in for the claude CLI in the Unattended Mode tests.
#
# It reads the scenario file $FAKE_SCENARIO, which defines one bash function
# per turn: turn_planning_<k>, turn_ticket_<n>_<k>, decide_<k>. A turn
# function sets RESULT (the turn's final text) and may change the fake
# tracker through the helpers in _lib-unattended-test.sh. Optional: SUBTYPE
# (default success), COST (this turn's cost, default 0.5), EXIT (default 0),
# TOOL_TEXT (an extra tool_result line, e.g. a hook BLOCKED message), ERR_TEXT
# (a line on stderr), HANG (seconds to stay alive after the result).
#
# Like the real CLI, total_cost_usd is the SESSION's running total: the sum of
# COST over every turn of that session id.
#
# It logs one line per call to $FAKE_DIR/calls.log:
#   <key> <TAB> <new|resume|decide> <TAB> <session> <TAB> <prompt, one line>
# plus the raw argv to $FAKE_DIR/argv.log and selected env to $FAKE_DIR/env.log.
set -u
# shellcheck source=_lib-unattended-test.sh
. "$(dirname "$0")/_lib-unattended-test.sh"

prompt="" sid="" mode="" name="" decide=0
argv="$(printf "%s " "$@" | tr "\n" " ")"
while [ $# -gt 0 ]; do
  case "$1" in
    -p) prompt="$2"; shift 2 ;;
    --session-id) sid="$2"; mode=new; shift 2 ;;
    --resume) sid="$2"; mode=resume; shift 2 ;;
    --name) name="$2"; shift 2 ;;
    --json-schema) decide=1; shift 2 ;;
    *) shift ;;
  esac
done

if [ "$decide" = 1 ]; then key=decide; mode=decide
else key="${name##*:}"; key="${key//-/_}"; fi

count_file="$FAKE_DIR/count.$key"
k=$(( $(cat "$count_file" 2>/dev/null || echo 0) + 1 ))
printf '%s\n' "$k" > "$count_file"

printf '%s\t%s\t%s\t%s\n' "$key" "$mode" "$sid" "$(printf '%s' "$prompt" | tr '\n' ' ' | cut -c1-300)" >> "$FAKE_DIR/calls.log"
printf '%s\t%s\n' "$key" "$argv" >> "$FAKE_DIR/argv.log"
printf '%s\tsession_id=%s\tproxy=%s\tsupervised=%s\tumask=%s\tbgceiling=%s\n' "$key" "${CLAUDE_CODE_SESSION_ID:-}" \
  "${APEXYARD_APPROVAL_PROXY:-}" "${APEXYARD_UNATTENDED_SUPERVISED:-}" "$(umask)" "${CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS:-unset}" >> "$FAKE_DIR/env.log"
printf '%s' "$prompt" > "$FAKE_DIR/prompt.$key.$k"
printf '%s\n' "$$" > "$FAKE_DIR/pid.$key.$k"
# Snapshot the tracker when a session starts, for the sequential assertion.
[ "$mode" = new ] && fake_snapshot > "$FAKE_DIR/snap.$key"

RESULT="" SUBTYPE=success COST=0.5 EXIT=0 TOOL_TEXT="" ERR_TEXT="" HANG=0
# shellcheck source=/dev/null
. "$FAKE_SCENARIO"
fn="turn_${key}_${k}"; [ "$key" = decide ] && fn="decide_$k"
if declare -F "$fn" >/dev/null; then "$fn"; else RESULT="(fake-claude: no $fn defined)"; fi

if [ "$key" = decide ]; then
  [ -n "$RESULT" ] || RESULT='{"action":"halt","reason":"no decide script"}'
  jq -cn --argjson so "$RESULT" \
    '{type:"result", subtype:"success", is_error:false, total_cost_usd:0.01, structured_output:$so}'
  exit 0
fi

total_file="$FAKE_DIR/total.$sid"
total="$(awk -v a="$(cat "$total_file" 2>/dev/null || echo 0)" -v b="$COST" 'BEGIN { printf "%.6f", a + b }')"
printf '%s\n' "$total" > "$total_file"
jq -cn --arg sid "$sid" '{type:"system", subtype:"init", session_id:$sid}'
[ -n "$TOOL_TEXT" ] && jq -cn --arg t "$TOOL_TEXT" '{type:"user", message:{content:[{type:"tool_result", content:$t}]}}'
[ -n "$ERR_TEXT" ] && printf '%s\n' "$ERR_TEXT" >&2
if [ "$SUBTYPE" != none ]; then
  jq -cn --arg r "$RESULT" --arg st "$SUBTYPE" --arg sid "$sid" --argjson c "$total" \
    '{type:"result", subtype:$st, is_error:($st != "success"), result:$r, session_id:$sid, total_cost_usd:$c, num_turns:3}'
fi
[ "$HANG" -gt 0 ] && sleep "$HANG"
exit "$EXIT"
