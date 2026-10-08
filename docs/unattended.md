# Unattended Mode

Unattended Mode runs one PRD from its first ticket to its last with no owner
message. You start it with one human-only command, `/unattended-plan <prd>`.
A supervisor then does what you do today. It answers the session's questions
with the recommended option. It sends `/approve-design` and `/approve-merge`
when the session asks for them. It starts a fresh session for each ticket.

The workflow does not change. Gates, hooks, review markers, and Rex do not
change. There is no per-project setting. The command authorizes one run only.
The decision record is [AgDR-0222](agdr/AgDR-0222-unattended-supervisor-as-owner-proxy.md).

> **Status**: available. The first real run must use `--rehearse` (see the
> walkthrough).

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

## Plan

```bash
/unattended-plan <prd-path> --plan-only
```

This runs the planning session and writes `<prd-basename>.unattended.json`
next to the PRD. Edit the sidecar to reorder tickets, remove tickets, or mark a
ticket `owner_only`. An existing sidecar always wins.

## Run

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
| `--tmux` | Open a tmux window with the log, when you run inside tmux. |
| `--stop` | Remove the run token and stop after the current turn. |
| `--resume` | Reconcile with the tracker and continue at the first ticket that is not done. |

`--rehearse` pauses for a keypress before each approval, so it needs a
terminal. Run it from a terminal with `bin/apexyard unattended-plan <prd>
--rehearse`. Inside a Claude Code session, the skill prints that command.
Press Enter to send the approval. Type `q` and Enter to stop the run.

## Watch

```bash
tail -f .claude/session/unattended/<prd-slug>/supervisor.log
/unattended-plan <prd-path> --status
```

## Walkthrough: the first run of a PRD

This walkthrough takes one PRD of a registered project from no tickets to a
finished run. Each step names what to check before the next one.

1. Plan the tickets. Check the sidecar that this writes next to the PRD.

   ```bash
   /unattended-plan docs/prds/PRD-003-search.md --plan-only
   ```

   - Each story of the PRD has one ticket. The epic is in `epic`.
   - The order follows the `Blocked by #N` references.
   - Edit the sidecar now to reorder tickets, remove tickets, mark a ticket
     `owner_only`, or set `config.execution_prompt` and `config.notify_webhook`.
2. Print the plan and every call. No model runs.

   ```bash
   /unattended-plan docs/prds/PRD-003-search.md --dry-run
   ```

3. Rehearse the first ticket from a terminal. Watch it through its first
   approval.

   ```bash
   bin/apexyard unattended-plan docs/prds/PRD-003-search.md --rehearse --tickets 41
   ```

   - Press Enter at the `[rehearse] About to send: /approve-merge ...` prompt.
   - Check that the merge went through the normal merge gate.
   - Check that the CEO marker has a `proxy=` line.
   - Check that `approvals.jsonl` has a `sent` line and a `merge-outcome` line.
   - This step also verifies the one undocumented mechanism: a slash command
     sent as the prompt of a resumed `-p` turn runs the human-only skill.
4. Start the run and leave.

   ```bash
   /unattended-plan docs/prds/PRD-003-search.md --tmux
   ```

   The command prints the PID and the log path. You can close the session.
   `--tmux` opens a tmux window with the log when you are inside tmux.
5. Read the summary when you return. It is at
   `.claude/session/unattended/<project>-<prd>/summary.md`.
6. Clear each needs-owner item. Then continue the run:

   ```bash
   /unattended-plan docs/prds/PRD-003-search.md --resume
   ```

   `--resume` skips each ticket that is closed with a merged PR. It starts at
   the first ticket that is not done.

## Notifications

The supervisor notifies you on a halt, at the end of a run, and on each
needs-owner item:

- It sends a desktop notification with `notify-send` when `DISPLAY` or
  `WAYLAND_DISPLAY` is set.
- It sends a JSON POST to `config.notify_webhook` when the sidecar sets an
  `http` or `https` URL. Use `https`: the body carries the PRD path and the
  needs-owner detail. The body holds `event`, `run`, `prd`, `project`,
  `ticket`, `message`, and `summary`. `ticket` is `null` for a run-level
  item, such as one from the planning session.
- A failed notification is logged and never stops the run.

## The summary

`summary.md` has these parts, in this order:

1. The result (`done` or `halted`), the count of tickets done, the PRD, the
   project, the epic, the run id, the start and finish times, and the cost.
2. **Tickets**: one row per ticket with its status, branch, PR link, turns,
   cost, and Rex rounds.
3. **Needs owner**: each item with its code and the exact detail.
4. **Approvals sent**: one row per line of `approvals.jsonl`.
5. **Halt reason** and **Resume**, only when the run halted.

## Stop and resume

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

Before it sends `/approve-design` or `/approve-merge`, the supervisor checks
that:

- the PR's branch names the ticket (`{type}/GH-<n>-...`, `{type}/#<n>-...`,
  or `{type}/<n>-...`),
- the ticket has no other open PR that already got an approval,
- the PR is open,
- Rex's marker matches the PR HEAD,
- a Rex review posted on the PR names that HEAD in its "Reviewed commit"
  footer, and
- the run token is the same file the run started with.

Before `/approve-merge` it also checks that the PR is not a draft and CI is
not red.

The supervisor sends a slash command only when it built the command after
these checks. Any other reply that starts with `/` goes to the child as plain
text. A project whose branches use another ticket-ID prefix fails the branch
check, and the run halts with no progress.

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

## Files

Each run keeps its files in `.claude/session/unattended/<project>-<prd>/`:

| File | Content |
|---|---|
| `run.token` | `run_id`, `prd`, `project`, `started_by`, `started_at`. |
| `state.json` | The epic, each ticket's status, session, branch, PR, turns, and cost, the needs-owner items, and the halt reason. |
| `lock` | The PID of the running supervisor. |
| `stop` | Created by `--stop`. |
| `approvals.jsonl` | One line per proxied approval. |
| `supervisor.log` | One line per supervisor decision. |
| `console.log` | The detached supervisor's output. |
| `logs/planning/turn-<k>.jsonl`, `logs/ticket-<n>/turn-<k>.jsonl` | The full stream of each child turn. |
| `summary.md` | The run summary. |

## Audit

Each `approvals.jsonl` line holds `at`, `run`, `ticket`, `pr`, `kind`, `head`,
`rex`, `command`, `result`, and `started_by`. The supervisor writes a line with
`result: "sent"` when it sends an approval. It writes a `merge-outcome` line
with `result: "merged"` after it verifies the merge.

`/approve-merge` and `/approve-design` refuse a proxied approval when no run
token for that run id exists. They only read the token. A proxied CEO marker
looks like this:

```text
sha=<head>
approved_by=user
approved_at=2026-10-08T12:00:00Z
skill_version=2
approval_summary="[proxy: run=<id> ticket=12] /approve-merge acme/widget#101"
proxy="unattended-plan run=<id> prd=<path> ticket=12 started_by=<owner session>"
```

The design marker stays one bare SHA, so `approvals.jsonl` is its only audit
record.

Each proxied merge leaves two records:

- one `proxy="unattended-plan run=<id> ..."` line in the CEO marker, with
  `approved_by=user` unchanged, and
- one line in `.claude/session/unattended/<prd-slug>/approvals.jsonl`.

## Limits

- The supervisor runs on your machine, not in the cloud. A cloud routine cannot
  reach the local workspace, the markers, or a local stack.
- The supervisor never enters credentials, creates accounts, or edits secrets.
- A child session runs as the same OS user as the supervisor. It can write
  the state directory, the review markers, and the sidecar. The supervisor
  cannot keep a secret from it. The supervisor therefore detects tampering
  instead of preventing it:
  - It halts when the run token disappears or changes during the run.
  - It halts when the sidecar changes during the run.
  - It requires a posted Rex review for HEAD, not only the marker file.
  - It reads every template once, before the first child runs.
  - It creates the state, the token, and the logs with mode `600`.
- A model in an attended session can run `unattended-plan.sh` through Bash
  and skip the human-only skill. AgDR-0222 accepts this. The merge gates,
  the audit log, and `approvals.jsonl` still record every merge.
- One mechanism is not documented: a slash command in a resumed `-p` turn.
  `--rehearse` verifies it on the first run.
