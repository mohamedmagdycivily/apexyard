---
id: AgDR-0222
timestamp: 2026-10-08T21:45:00Z
agent: tech-lead
model: claude-opus-5-5
trigger: user-prompt
status: executed
category: patterns
projects: [apexyard]
---

<!-- Uses the controlled technical writing profile in .claude/rules/writing-standard.md. -->

# Run a PRD unattended through a bash supervisor that proxies the owner

> In the context of a PRD that needs the owner at every approval, facing an
> owner who wants to leave for a day, I decided to add a bash supervisor that
> one human-only command starts. The supervisor works the PRD's tickets in
> series and sends the owner's approval commands into each child session. This
> keeps every gate, hook, and marker unchanged. I accepted that a proxied
> approval is delegated by the owner, not typed by the owner.

## Context

- Today one PRD needs the owner at three points per ticket. The owner runs
  `/approve-design`, runs `/approve-merge`, and starts a new session for the
  next ticket.
- The approval skills carry `disable-model-invocation: true` (AgDR-0110). The
  model cannot call them through the Skill tool.
- A slash command passed as the prompt of a headless `claude -p` turn is a user
  invocation. A supervisor can send `/approve-merge 12` as the next user
  message, exactly as the owner types it.
- The owner set three constraints on 2026-10-08:
  1. Do not change the workflow, the gates, or the hooks.
  2. Add no per-project setting. One command authorizes one run.
  3. The unit of work is the ticket. Tickets run in series. One ticket is one
     session, one branch, and one PR, merged before the next ticket starts.

## Options Considered

| Option | Pros | Cons |
|--------|------|------|
| 1. Rewrite the merge gates with `approved_by=policy` and an `/auto-merge` path | No supervisor process. | Changes every merge gate and its tests. The owner rejected it. |
| 2. Add a per-project `unattended` registry flag and a guard hook | One switch per project. | A standing setting outlives the run. It adds a hook. The owner rejected it. |
| 3. Run one child session per epic | Fewer sessions. | One session spans many PRs. Its context grows and PRs run together. The owner rejected it: the unit is the ticket. |
| 4. Use a long-lived interactive Claude session as the supervisor | No new script. | Its context grows without bound. It dies with the terminal. A test cannot drive it. |
| 5. Use a bash supervisor that a human-only `/unattended-plan <prd>` command starts | No gate, hook, or marker change. One run token per run. Testable with a fake CLI. The model runs only in child sessions. | One mechanism is unverified: a slash command in a resumed `-p` turn. A proxied approval is delegated, not typed. |

## Decision

Chosen: **option 5**, because it is the only option that meets all three owner
constraints. It changes no gate and adds no project setting. It also keeps the
ticket as the unit of work.

The design has these parts:

1. `/unattended-plan <prd>` is human-only. It writes a run token and starts
   `bin/unattended-supervisor` as a detached process.
2. A planning child session finds the PRD's tickets. It files the missing
   tickets through the existing ticket skills. The supervisor verifies each
   number and writes a sidecar file next to the PRD.
3. The supervisor runs one fresh headless child session per ticket, in order.
   It starts ticket N+1 only after it verifies that ticket N's PR is merged and
   the ticket is closed.
4. The child ends each turn with one structured line. The supervisor answers a
   question with the recommended option. It sends `/approve-design` or
   `/approve-merge` only after its own checks pass.
5. A proxied merge writes one extra `proxy=` line in the CEO marker and one line
   in `approvals.jsonl`. `approved_by=user` does not change.

## Consequences

- No file under `.claude/hooks/` changes. Every merge passes the same gates.
- An owner who never runs `/unattended-plan` sees no change.
- The supervisor answers questions with the recommended option. A wrong
  recommendation reaches a PR without owner review. Rex, CI, and the gates still
  review that PR.
- The slash command in a resumed `-p` turn is expected to work but is not
  documented. `--rehearse` verifies it on the first real run. The fallback runs
  the approval in its own fresh session. This changes one function.
- Anyone with disk access can write a run token. The human-only command, the
  audit log, and the refusal inside a supervised child are the backstops. The
  framework takes the same position on review markers.
- A child session runs as the same OS user as the supervisor, so it can write
  the run token, the review markers, and the sidecar. No file-based control
  can stop that without a hook change, which this design excludes. The
  supervisor detects tampering instead. It halts when the token or the
  sidecar changes during a run. It requires a posted Rex review for HEAD. It
  sends a slash command only when it built that command itself. The PR #7
  security review found these gaps. The owner accepts the residual risk by
  merging that PR.
- `/unattended-plan` joins the human-only list in
  `test_skill_invocability_gates.sh`. Its invocation is the owner's delegation
  of approval for that run.

## Artifacts

- Epic: mohamedmagdycivily/apexyard#1
- Tickets: #2 (docs), #3 (supervisor), #4 (approval audit), #5 (polish)
- Child rules: `.claude/rules/unattended-mode.md`
- Operator guide: `docs/unattended.md`
