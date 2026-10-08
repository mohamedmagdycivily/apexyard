<!-- Generic work block of an Unattended Mode ticket session, used when the sidecar sets no execution_prompt (AgDR-0222). Uses the controlled technical writing profile in .claude/rules/writing-standard.md. -->

## Work the ticket

Work ticket #{{TICKET}} of the PRD under the ApexYard SDLC, exactly as an
attended session does:

1. Run `/start-ticket {{REPO}}#{{TICKET}}`.
2. Read the ticket, its comments, and its acceptance criteria.
3. Reconcile the ticket with the code per `.claude/rules/reconcile-before-build.md`.
4. Create the branch, build, and run the tests, lint, typecheck, and build.
5. Open the PR and run `/code-review`. Fix every finding Rex raises.
6. Ask for the approvals with `UNATTENDED-APPROVE`.
7. After the merge, run QA against every acceptance criterion. Then close the
   ticket.
8. End with `UNATTENDED-NEXT: ticket={{TICKET}} done pr=<p>`.
