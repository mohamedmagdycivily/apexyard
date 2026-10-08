<!-- First prompt of the Unattended Mode planning session (AgDR-0222). bin/unattended-supervisor fills the {{...}} fields. Uses the controlled technical writing profile in .claude/rules/writing-standard.md. -->

# Planning session for {{PRD}}

This is the planning session of an Unattended Mode run. Find or file the
tickets for one PRD. Build nothing.

- Project: {{PROJECT}}
- Tracker repo: {{REPO}}
- Workspace: {{WORKSPACE}}
- PRD: {{PRD}}

## Steps

1. Read the PRD.
2. Search the tracker for tickets that already reference this PRD. Use
   `tracker_list {{REPO}} search=<PRD id or title> state=all` from
   `.claude/hooks/_lib-tracker.sh`. Also read the epic's sub-issues.
3. When the epic ticket is missing, file it with `/feature`.
4. When a story ticket is missing, file it with `/tickets-batch`, `/feature`,
   or `/task`. File one ticket for each user story in scope.
   - Add `Refs #<epic>` to each story ticket.
   - Add `Blocked by #<n>` when one story depends on another.
5. File only the missing tickets. Never file a duplicate.
6. Do not create a branch, edit code, or open a PR.

## End the session

End your last turn with this line. List the open story tickets in dependency
order. Do not list the epic or any sub-epic in `tickets=`: they group
other tickets and are never worked on their own.

    UNATTENDED-TICKETS: epic=<n> tickets=<n1>,<n2>,...
