#!/bin/bash
# _lib-unattended-proxy.sh — proxied-approval checks for /approve-merge and
# /approve-design (AgDR-0222, PRD-001 US-6).
#
# bin/unattended-supervisor exports APEXYARD_APPROVAL_PROXY into each child
# session:
#   APEXYARD_APPROVAL_PROXY="unattended-plan run=<id> prd=<path> ticket=<n> started_by=<owner>"
# When that variable is set, an /approve-* command in the session was sent by
# the supervisor on the owner's behalf. The approve skills then:
#   1. require the run token for that run id (unattended_proxy_check), and
#   2. /approve-merge only: write one extra `proxy="..."` line in the CEO
#      marker and prefix approval_summary with `[proxy: ...]`.
# approved_by=user does not change. The merge gate parses the CEO marker per
# key, so the extra line does not change its result. The design marker stays
# a bare SHA, because its gate reads the whole file.
#
# With the variable unset, every function is a no-op that succeeds, so the
# attended flow is unchanged.
#
# Functions:
#   unattended_proxy_active            exit 0 when the variable is set
#   unattended_proxy_run_id            print the run id from the variable
#   unattended_proxy_check <ops_root>  exit 0 when not proxied, or when a run
#                                      token with the matching run_id exists
#                                      under <ops_root>/.claude/session/
#                                      unattended/*/run.token; else print the
#                                      refusal on stderr and exit 1
#   unattended_proxy_value             the variable, sanitised (no quotes,
#                                      backticks, dollars, backslashes,
#                                      newlines), at most 300 chars
#   unattended_proxy_marker_line       print `proxy="<value>"`, or nothing
#   unattended_proxy_summary_prefix    print `[proxy: run=<id> ticket=<n>] `,
#                                      or nothing

unattended_proxy_active() { [ -n "${APEXYARD_APPROVAL_PROXY:-}" ]; }

unattended_proxy_value() {
  printf '%s' "${APEXYARD_APPROVAL_PROXY:-}" | tr '\n\r' '  ' | tr -d '"`$\\' | cut -c1-300
}

_unattended_proxy_field() { # <key>
  unattended_proxy_value | tr ' ' '\n' | sed -n "s/^$1=//p" | head -1
}

unattended_proxy_run_id() { _unattended_proxy_field run; }

unattended_proxy_check() {
  unattended_proxy_active || return 0
  local ops_root="${1:-.}" run_id tok
  run_id="$(unattended_proxy_run_id)"
  if [ -z "$run_id" ]; then
    echo "REFUSED: APEXYARD_APPROVAL_PROXY is set but names no run id. A proxied approval needs a live Unattended Mode run." >&2
    return 1
  fi
  for tok in "$ops_root"/.claude/session/unattended/*/run.token; do
    [ -f "$tok" ] || continue
    if [ "$(sed -n 's/^run_id=//p' "$tok" | head -1)" = "$run_id" ]; then
      return 0
    fi
  done
  echo "REFUSED: no run token for Unattended Mode run '$run_id' under $ops_root/.claude/session/unattended/. The owner stopped the run (--stop) or the token was removed. A proxied approval is not allowed without it." >&2
  return 1
}

unattended_proxy_marker_line() {
  unattended_proxy_active || return 0
  printf 'proxy="%s"\n' "$(unattended_proxy_value)"
}

unattended_proxy_summary_prefix() {
  unattended_proxy_active || return 0
  local t; t="$(_unattended_proxy_field ticket)"
  printf '[proxy: run=%s%s] ' "$(unattended_proxy_run_id)" "${t:+ ticket=$t}"
}
