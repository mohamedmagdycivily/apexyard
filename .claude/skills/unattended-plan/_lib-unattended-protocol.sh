#!/bin/bash
# _lib-unattended-protocol.sh — parse the end-line protocol a supervised
# child session uses to talk to bin/unattended-supervisor (AgDR-0222).
#
# The child ends a turn with exactly one structured line. The full table is
# in .claude/rules/unattended-mode.md. This library turns a turn's final text
# into one normalised record the supervisor can switch on.
#
# Functions:
#   up_end_line <text>        print the LAST line that starts with
#                             UNATTENDED-<KIND> (ignoring UNATTENDED-STATUS),
#                             or nothing. Leading spaces, '>' quotes and
#                             backticks around the line are tolerated.
#   up_is_last_line <text>    exit 0 when that line is the last non-empty
#                             line of the text, 1 otherwise.
#   up_parse <line>           print "kind<TAB>field1<TAB>field2..." for one
#                             protocol line, or "invalid<TAB><line>":
#                               tickets  <epic>  <n1,n2,...>
#                               ask      <question>  <options>  <recommended>
#                               approve  design|merge  <pr>
#                               next     <ticket>  <pr>
#                               done
#                               blocked  <code>  <detail>
#   up_status <text>          print "rex<TAB>round<TAB>ci" from the last
#                             UNATTENDED-STATUS line, or nothing.
#   up_blocked_code_valid <code>  exit 0 for a known BLOCKED code.
#
# Pure bash + sed. No jq. Safe to source from the supervisor and from tests.

UP_BLOCKED_CODES="credentials account device privileged ambiguous-scope external-dependency"

# Strip decoration a model may put around the line: leading spaces, a
# markdown quote, inline-code backticks, bold markers, trailing spaces/CR.
_up_clean() {
  printf '%s' "$1" | tr -d '\r' | sed -E 's/^[[:space:]>*`]+//; s/[[:space:]*`]+$//'
}

up_end_line() {
  local text="$1" line cleaned found=""
  while IFS= read -r line || [ -n "$line" ]; do
    cleaned=$(_up_clean "$line")
    case "$cleaned" in
      UNATTENDED-STATUS:*) ;;
      UNATTENDED-TICKETS:*|UNATTENDED-ASK:*|UNATTENDED-APPROVE:*|UNATTENDED-NEXT:*|UNATTENDED-DONE*|UNATTENDED-BLOCKED:*)
        found="$cleaned" ;;
    esac
  done <<< "$text"
  [ -n "$found" ] && printf '%s\n' "$found"
}

up_is_last_line() {
  local text="$1" last="" line cleaned
  while IFS= read -r line || [ -n "$line" ]; do
    cleaned=$(_up_clean "$line")
    [ -n "$cleaned" ] && last="$cleaned"
  done <<< "$text"
  case "$last" in
    UNATTENDED-STATUS:*) return 1 ;;
    UNATTENDED-*) return 0 ;;
  esac
  return 1
}

# Read key=<value> out of a space-separated "k=v k=v" list.
_up_kv() {
  printf '%s\n' "$1" | tr ' ' '\n' | sed -n "s/^$2=//p" | head -1
}

_up_trim() {
  printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

up_parse() {
  local line rest kind pr epic tickets ticket code detail
  line=$(_up_clean "$1")
  case "$line" in
    UNATTENDED-TICKETS:*)
      rest=${line#UNATTENDED-TICKETS:}
      epic=$(_up_kv "$rest" epic | tr -d '#')
      tickets=$(_up_kv "$rest" tickets | tr -d '# ')
      if printf '%s' "$tickets" | grep -Eq '^[0-9]+(,[0-9]+)*$' \
         && { [ -z "$epic" ] || printf '%s' "$epic" | grep -Eq '^[0-9]+$'; }; then
        printf 'tickets\t%s\t%s\n' "$epic" "$tickets"; return 0
      fi ;;
    UNATTENDED-ASK:*)
      rest=$(_up_trim "${line#UNATTENDED-ASK:}")
      local q opts rec part
      q="$rest"; opts=""; rec=""
      if printf '%s' "$rest" | grep -q '|'; then
        q=$(_up_trim "${rest%%|*}")
        while IFS= read -r part; do
          part=$(_up_trim "$part")
          case "$part" in
            options:*) opts=$(_up_trim "${part#options:}") ;;
            recommended:*) rec=$(_up_trim "${part#recommended:}") ;;
          esac
        done < <(printf '%s\n' "${rest#*|}" | tr '|' '\n')
      fi
      if [ -n "$q" ]; then
        printf 'ask\t%s\t%s\t%s\n' "$q" "$opts" "$rec"; return 0
      fi ;;
    UNATTENDED-APPROVE:*)
      rest=$(_up_trim "${line#UNATTENDED-APPROVE:}")
      kind=${rest%% *}
      pr=$(_up_kv "$rest" pr | tr -d '#')
      if { [ "$kind" = design ] || [ "$kind" = merge ]; } \
         && printf '%s' "$pr" | grep -Eq '^[0-9]+$'; then
        printf 'approve\t%s\t%s\n' "$kind" "$pr"; return 0
      fi ;;
    UNATTENDED-NEXT:*)
      rest=${line#UNATTENDED-NEXT:}
      ticket=$(_up_kv "$rest" ticket | tr -d '#')
      pr=$(_up_kv "$rest" pr | tr -d '#')
      if printf '%s' "$ticket" | grep -Eq '^[0-9]+$' \
         && printf '%s' "$pr" | grep -Eq '^[0-9]+$'; then
        printf 'next\t%s\t%s\n' "$ticket" "$pr"; return 0
      fi ;;
    UNATTENDED-DONE|UNATTENDED-DONE:*)
      printf 'done\n'; return 0 ;;
    UNATTENDED-BLOCKED:*)
      rest=$(_up_trim "${line#UNATTENDED-BLOCKED:}")
      code=${rest%% *}
      detail=""
      [ "$code" != "$rest" ] && detail=$(_up_trim "${rest#* }")
      if up_blocked_code_valid "$code"; then
        printf 'blocked\t%s\t%s\n' "$code" "$detail"; return 0
      fi ;;
  esac
  printf 'invalid\t%s\n' "$line"
  return 1
}

up_status() {
  local text="$1" line cleaned found=""
  while IFS= read -r line || [ -n "$line" ]; do
    cleaned=$(_up_clean "$line")
    case "$cleaned" in UNATTENDED-STATUS:*) found="${cleaned#UNATTENDED-STATUS:}" ;; esac
  done <<< "$text"
  [ -z "$found" ] && return 1
  printf '%s\t%s\t%s\n' "$(_up_kv "$found" rex)" "$(_up_kv "$found" round)" "$(_up_kv "$found" ci)"
}

up_blocked_code_valid() {
  local c
  for c in $UP_BLOCKED_CODES; do [ "$c" = "${1:-}" ] && return 0; done
  return 1
}
