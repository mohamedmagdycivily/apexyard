# Unattended Mode — Rules for a Supervised Child Session

Load this rule when `APEXYARD_UNATTENDED_SUPERVISED=1` is set in your
environment. That variable means `bin/unattended-supervisor` started this
session. The owner started the supervisor with the human-only command
`/unattended-plan <prd>`. The decision record is AgDR-0222.

## What does not change

Work exactly as an attended session works.

- Follow `workflows/sdlc.md` and every gate in `.claude/rules/workflow-gates.md`.
- Run `/start-ticket`, build, test, open the PR, and run `/code-review`.
- Let every hook run. A hook block is a real block.
- Run QA against the ticket's acceptance criteria after the merge. Then close
  the ticket.

## What is different

The supervisor stands in for the owner. It reads the last line of each of
your turns. It sends the next user message.

1. `AskUserQuestion` is not available. Ask in your last line instead.
2. Never invoke `/approve-merge`, `/approve-design`, or `/approve-architecture`
   yourself. Ask the supervisor for them in your last line.
3. Never write a review marker or an approval marker.
4. A `/approve-*` command that the supervisor sends is the owner's approval by
   delegation. The skill records it with a `proxy=` audit line.
5. An execution prompt can say "ask me to run `/approve-merge`". Read that as
   "end the turn with `UNATTENDED-APPROVE`". Every other line of that prompt
   stands.

## One ticket, one branch, one PR

- This session covers one ticket only. The supervisor names it in the prompt.
- Start from an updated `main`.
- Create one branch `{type}/{TICKET-ID}-{description}`.
- Open one PR. Never open a second PR.
- Never use `/fan-out` across tickets. Never start another ticket.
- A planning session builds nothing. It only finds or files tickets.

## End each turn with one structured line

When you need the supervisor, make your final line exactly one of these lines.
Put nothing after it.

| Last line | Use it when | Supervisor reply |
|---|---|---|
| `UNATTENDED-TICKETS: epic=<n> tickets=<n1>,<n2>,...` | A planning session found or filed every ticket. List them in dependency order. | Ends the planning session. |
| `UNATTENDED-ASK: <question> \| options: <a>; <b> \| recommended: <x>` | You need a decision. | `Go with the recommended option: <x>. Continue.` |
| `UNATTENDED-APPROVE: design pr=<n>` | Rex approved the PR at HEAD and the PR touches UI. | `/approve-design <n>` after its checks pass. |
| `UNATTENDED-APPROVE: merge pr=<n>` | Rex approved the PR at HEAD and CI is not red. | `/approve-merge <n>` after its checks pass. |
| `UNATTENDED-NEXT: ticket=<n> done pr=<p>` | The PR merged, QA passed, and the ticket is closed. | Ends this session and starts the next ticket. |
| `UNATTENDED-DONE` | No ticket of the PRD is left. | Writes the summary and exits. |
| `UNATTENDED-BLOCKED: <code> <detail>` | Only the owner can resolve the problem. | Records a needs-owner item. |

You can also write one non-terminal status line before the last line:
`UNATTENDED-STATUS: rex=<verdict> round=<k> ci=<state>`.

Give a `recommended:` option whenever you can. A question with no
recommendation costs a separate model call.

## Blocked codes

Use one of these codes in `UNATTENDED-BLOCKED`:

| Code | Meaning |
|---|---|
| `credentials` | The work needs a secret, a key, or a sign-in. |
| `account` | The work needs a new account or a paid plan. |
| `device` | The work needs a physical device or a human check. |
| `privileged` | The work needs `sudo`, a production change, or a hook bypass. |
| `ambiguous-scope` | The ticket and the PRD disagree and no option is safe. |
| `external-dependency` | The work waits on a third party. |

Never enter credentials, create accounts, or edit secrets. Report them with
`UNATTENDED-BLOCKED` instead.

## When the supervisor stops

The supervisor stops the run and records a needs-owner item when:

- `block-privileged-escalation.sh`, `check-secrets.sh`, or `block-main-push.sh`
  blocks a command.
- Rex requests changes three times on one PR.
- `/approve-merge` refuses three times on one PR.
- CI is red at approval time twice.
- Two turns in a row make no progress.
- The run cost reaches its ceiling, or the owner runs `--stop`.

Operator guide: `docs/unattended.md`.
