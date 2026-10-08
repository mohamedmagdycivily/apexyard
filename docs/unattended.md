# Unattended Mode

Unattended Mode runs one PRD from its first ticket to its last with no owner
message. You start it with one human-only command, `/unattended-plan <prd>`.
A supervisor then does what you do today. It answers the session's questions
with the recommended option. It sends `/approve-design` and `/approve-merge`
when the session asks for them. It starts a fresh session for each ticket.

The workflow does not change. Gates, hooks, review markers, and Rex do not
change. There is no per-project setting. The command authorizes one run only.
The decision record is [AgDR-0222](agdr/AgDR-0222-unattended-supervisor-as-owner-proxy.md).

> **Status**: this page describes the design. The supervisor ships in a later
> PR. Sections marked *(ships with the supervisor)* describe behaviour that is
> not available yet.

## Terms

| Term | Meaning |
|---|---|
| Supervisor | `bin/unattended-supervisor`, the detached bash process that drives one PRD run. |
| Child session | One fresh headless Claude Code session that the supervisor starts. |
| Planning session | The first child session. It finds or files the PRD's tickets. It builds nothing. |
| Ticket session | A child session that works one ticket. |
| Run token | The file `/unattended-plan` writes to authorize proxied approvals for one run. |
| Proxied approval | An `/approve-*` command the supervisor sends on the owner's behalf. |
| Sidecar | The JSON file next to the PRD that holds the run config and the ticket order. |
| Needs-owner item | A recorded stop that only the owner can resolve. |

## How a run works

1. The supervisor starts a planning session. That session reads the PRD and
   searches the tracker for its tickets. It files the missing epic and story
   tickets with `/tickets-batch`, `/feature`, or `/task`.
2. The supervisor verifies every ticket number and writes the sidecar.
3. For each ticket in order, the supervisor starts a fresh ticket session. The
   session runs `/start-ticket`, builds, tests, opens one PR, and runs
   `/code-review`.
4. The session asks for each approval. The supervisor checks the PR and sends
   the approval command.
5. After the merge, the session runs QA and closes the ticket.
6. The supervisor verifies that the PR merged and the ticket closed. Then it
   starts the next ticket.

Tickets always run in series. One ticket is one session, one branch, and one
PR. The supervisor never starts ticket N+1 while ticket N's PR is open.

## Plan *(ships with the supervisor)*

```bash
/unattended-plan <prd-path> --plan-only
```

This runs the planning session and writes `<prd-basename>.unattended.json`
next to the PRD. Edit the sidecar to reorder tickets, remove tickets, or mark a
ticket `owner_only`. An existing sidecar always wins.

## Run *(ships with the supervisor)*

```bash
/unattended-plan <prd-path> --dry-run     # print the plan and every call, run no model
/unattended-plan <prd-path> --rehearse    # run for real, pause before each approval
/unattended-plan <prd-path>               # run, then leave
```

Other flags:

| Flag | Effect |
|---|---|
| `--project <name>` | Use this registered project when the PRD path does not resolve one. |
| `--tickets 12,14` | Work only these tickets. |
| `--status` | Print the run state. |
| `--stop` | Remove the run token and stop after the current turn. |
| `--resume` | Reconcile with the tracker and continue at the first ticket that is not done. |

## Watch *(ships with the supervisor)*

```bash
tail -f .claude/session/unattended/<prd-slug>/supervisor.log
/unattended-plan <prd-path> --status
```

## Stop and resume *(ships with the supervisor)*

`--stop` removes the run token and creates the stop file. The supervisor
finishes the current turn, sends nothing more, and writes `summary.md`.

`--resume` first reconciles each ticket from the tracker and GitHub:

- A closed ticket with a merged PR is done, whatever the state file says.
- A running ticket with an open PR resumes its session.
- A running ticket with no PR starts a fresh session.

## The protocol

A child session ends each turn with one structured last line. The full table is
in [`.claude/rules/unattended-mode.md`](../.claude/rules/unattended-mode.md).

| Last line | Supervisor reply |
|---|---|
| `UNATTENDED-TICKETS: epic=<n> tickets=<n1>,<n2>,...` | Verify, order, and write the sidecar. |
| `UNATTENDED-ASK: <q> \| options: <a>; <b> \| recommended: <x>` | `Go with the recommended option: <x>. Continue.` |
| `UNATTENDED-ASK: <q>` with no recommendation | One short read-only model call decides the reply. |
| `UNATTENDED-APPROVE: design pr=<n>` | `/approve-design <n>` after the checks. |
| `UNATTENDED-APPROVE: merge pr=<n>` | `/approve-merge <n>` after the checks. |
| `UNATTENDED-NEXT: ticket=<n> done pr=<p>` | Verify, then start the next ticket. |
| `UNATTENDED-DONE` | Write the summary and exit. |
| `UNATTENDED-BLOCKED: <code> <detail>` | Record a needs-owner item. |

When the last line is missing, the supervisor nudges once. Then it makes the
decide call. Then it records a needs-owner item.

### Approval checks

Before it sends `/approve-design`, the supervisor checks that:

- the PR is open, and
- Rex's marker matches the PR HEAD.

Before it sends `/approve-merge`, the supervisor checks that:

- the PR is open and not a draft,
- CI is not red,
- Rex's marker matches the PR HEAD, and
- the run token exists.

## Stop conditions

| Condition | Result |
|---|---|
| `block-privileged-escalation.sh`, `check-secrets.sh`, or `block-main-push.sh` blocks a command | Halt. |
| `UNATTENDED-BLOCKED` and a later ticket is blocked by this ticket | Needs-owner item, halt. |
| `UNATTENDED-BLOCKED` and no later ticket depends on this ticket | Needs-owner item, continue. |
| Rex requests changes three times on one PR | Needs-owner item, halt. |
| `/approve-merge` refuses three times on one PR | Needs-owner item, halt. |
| CI is red at approval time twice | Needs-owner item, halt. |
| A turn fails on budget or timeout | Retry once if the turn made progress. Else needs-owner item. |
| Two turns in a row make no progress | Halt. |
| The run token is missing at an approval | Halt. |
| The stop file exists | Finish the turn, then halt. |
| The run cost reaches `max_run_usd` | Halt. |

## The sidecar

```json
{ "config": { "execution_prompt": "", "max_turn_usd": 15, "max_ticket_usd": 60,
              "max_run_usd": 300, "turn_timeout_s": 5400, "notify_webhook": "" },
  "epic": 11,
  "tickets": [ { "n": 12, "title": "Sign-up", "blocked_by": [], "owner_only": false, "ui": true },
               { "n": 13, "title": "Availability", "blocked_by": [12], "owner_only": false, "ui": true } ] }
```

| Key | Default | Meaning |
|---|---|---|
| `config.execution_prompt` | empty | A prompt file that each ticket session receives first. |
| `config.max_turn_usd` | 15 | The budget for one child turn. |
| `config.max_ticket_usd` | 60 | The cost ceiling for one ticket. |
| `config.max_run_usd` | 300 | The cost ceiling for the run. |
| `config.turn_timeout_s` | 5400 | The wall-clock limit for one child turn. |
| `config.notify_webhook` | empty | A URL that receives a POST on halt, done, and each needs-owner item. |

## Audit

Each proxied merge leaves two records:

- one `proxy="unattended-plan run=<id> ..."` line in the CEO marker, with
  `approved_by=user` unchanged, and
- one line in `.claude/session/unattended/<prd-slug>/approvals.jsonl`.

## Limits

- The supervisor runs on your machine, not in the cloud. A cloud routine cannot
  reach the local workspace, the markers, or a local stack.
- The supervisor never enters credentials, creates accounts, or edits secrets.
- Anyone with disk access can write a run token. The human-only command, the
  audit log, and the refusal inside a supervised child are the backstops.
- One mechanism is not documented: a slash command in a resumed `-p` turn.
  `--rehearse` verifies it on the first run.
