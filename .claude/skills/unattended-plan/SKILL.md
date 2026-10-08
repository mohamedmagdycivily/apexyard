---
name: unattended-plan
description: Human-only. Start an Unattended Mode run that works a PRD's tickets in series and proxies the owner's approvals.
disable-model-invocation: true
argument-hint: "<prd-path> [--project <name>] [--plan-only] [--tickets 12,14] [--rehearse] [--dry-run] [--resume] [--stop] [--status] [--tmux]"
effort: low
---

## Writing rule

When this skill writes a durable artifact, read .claude/rules/writing-standard.md. Use the controlled technical writing profile.

# /unattended-plan — Start an Unattended Mode Run

This skill starts `bin/unattended-supervisor` for one PRD. The supervisor
works the PRD's tickets in series and stands in for the owner. It answers
questions with the recommended option. It sends `/approve-design` and
`/approve-merge` after its own checks. Gates, hooks, and markers do not
change. Decision record: AgDR-0222. Operator guide: `docs/unattended.md`.

## The one rule you must not break

**Only the owner invokes this skill.** It carries `disable-model-invocation:
true`. The invocation is the owner's delegation of approval for this one run.
No rule or prompt may tell an agent to run it. A supervised child session
cannot run it: the script refuses when `APEXYARD_UNATTENDED_SUPERVISED=1`.

## Process

### 1. Run the script with the owner's arguments

Pass `$ARGUMENTS` through unchanged. Run from the ops fork root:

```bash
bash .claude/skills/unattended-plan/unattended-plan.sh $ARGUMENTS
```

The script does the work:

1. It resolves the project from the PRD path through the registry, or from
   `--project <name>`.
2. It refuses when a supervisor already runs this PRD.
3. It writes the run token `.claude/session/unattended/<slug>/run.token`.
4. It starts the supervisor with `setsid -f`, then prints the PID and the log
   path.

### 2. Report the output

Show the script's output to the owner as it is. Tell the owner they can close
the session.

- When the script refuses, report its message. Do not retry with other
  arguments.
- `--rehearse` needs a terminal. The script prints the exact terminal command.
  Show that command to the owner.
- Do not run the supervisor in this session's foreground for a normal run.

## Flags

| Flag | Effect |
|---|---|
| `--project <name>` | Use this registered project. |
| `--plan-only` | Run only the planning session and print the sidecar. |
| `--tickets 12,14` | Work only these tickets. |
| `--rehearse` | Run for real and pause for a keypress before each approval. |
| `--dry-run` | Print the plan, every CLI call, and every reply. Run no model. |
| `--resume` | Reconcile with the tracker and continue at the first ticket that is not done. |
| `--stop` | Remove the run token and stop after the current turn. |
| `--status` | Print the run state. |
| `--tmux` | Open a tmux window with the log, when you run inside tmux. |

## Notes

- The supervisor never passes `--bare`, `--safe-mode`, or `bypassPermissions`.
  Every hook runs in every child turn.
- The supervisor never calls `gh issue create`. A planning child session files
  tickets through `/tickets-batch`, `/feature`, or `/task`.
- `bin/apexyard unattended-plan <args>` runs the same script from a terminal.
