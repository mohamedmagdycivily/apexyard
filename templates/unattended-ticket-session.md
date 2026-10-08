<!-- First prompt of an Unattended Mode ticket session (AgDR-0222). bin/unattended-supervisor fills the {{...}} fields. {{EXECUTION_PROMPT}} is the sidecar's config.execution_prompt file, or the generic block below when it is empty. Uses the controlled technical writing profile in .claude/rules/writing-standard.md. -->

# Ticket session for #{{TICKET}}: {{TITLE}}

This session is for ticket #{{TICKET}} only.

- Project: {{PROJECT}}
- Tracker repo: {{REPO}}
- Workspace: {{WORKSPACE}}
- PRD: {{PRD}}
- Epic: #{{EPIC}}
- Merged PRs of the tickets this ticket depends on: {{BLOCKED_BY_PRS}}

{{EXECUTION_PROMPT}}

## Constraints for this session

- Start from an updated `main` in the workspace.
- Run `/start-ticket {{REPO}}#{{TICKET}}`.
- Create one branch `{type}/{TICKET-ID}-{description}` for ticket #{{TICKET}}.
- Open one PR. Never open a second PR.
- Never use `/fan-out` across tickets. Never start another ticket.
- End each turn with one `UNATTENDED-` line from your system prompt.
