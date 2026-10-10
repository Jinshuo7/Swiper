# Standing instructions: finish SWIPR autonomously, using DeepSeek for the work and Codex sparingly

I am the owner. I am not a programmer, and I am away from home. I can only reach you through this
chat and the GitHub app on my phone. Your goal is to take SWIPR all the way to "ready for App
Store submission" without waiting for me. Never pause to wait for my reply.

## The main cost rule
Codex usage is scarce. DeepSeek usage and scripts are cheap. **Anything DeepSeek or a script can
do, DeepSeek or a script must do.** Codex only plans, reviews, and decides.

## Roles
- **Driver (this Pi session, deepseek-flash, effort high):** pick tickets, write ticket
  instructions, run the worker and reviewer, open PRs, and merge when allowed.
- **Worker:** do the implementation in this session or a separate Pi run, always in a fresh worktree
  under `/Users/beastmini/GitHub/Jinshuo7/SWIPR-worktrees/`.
- **Reviewer:** for each ticket, a SEPARATE fresh Pi run of deepseek-flash at effort max, started as
  its own command (check `pi --help` for the non-interactive option). Give it only the ticket,
  PROJECT-BRIEF.md, `gh pr diff`, the check results, and screenshots next to the approved
  references. Never this conversation. It answers ACCEPT or gives exact corrections.
- **Codex:** not used by you. The owner uses it manually for spot checks.

## Do this first (one time)
1. Merge PR #40 with a merge commit, if it is not merged yet.
2. Turn on branch protection for `main` (using `gh api`): require the `checks` status to pass,
   and block force-pushes and branch deletion. If you cannot, file a `needs-owner` issue with the
   exact clicks, then continue.
3. Keep the Mac awake while working (`caffeinate -dims` in the background).
4. Create the labels `needs-owner`, `milestone-report`, `provisional`, and `provisional-design`.
5. Have DeepSeek save these exact instructions as `docs/agents/OWNER-INSTRUCTIONS.md`, and add
   one line to `AGENTS.md` saying all agents must follow that file. Then a fresh chat can
   continue without me re-pasting anything.
6. Have DeepSeek write `docs/agents/PROJECT-BRIEF.md`: at most 2 pages summarizing the v1
   requirements from issue #24 and `docs/SPEC.md`, the roadmap order, and the approved visual
   references. Review it once. From then on, read the brief instead of rereading every doc.
   Open a full doc only when a ticket needs that specific section.

## Safety rules (never break these)
1. Use a fresh worktree and branch for every ticket; never commit to `main` directly.
2. Never reset, clean, stash, restore, rebase, or force-push. Delete only worktrees and branches
   you created, and only after their ticket is merged.
3. Never push to `main`. Every change goes through a PR.
4. **Merge only when ALL of these are true:** GitHub checks are green, the diff touches only the
   ticket's files, and every acceptance criterion is met based on the actual result. Use
   "Create a merge commit", then close the issue.
5. **Never make checks pass by weakening them.** No deleting, skipping, loosening, or
   expected-failure-marking of tests, and no CI edits to dodge a failure. If a test itself seems
   wrong, park it as `needs-owner`. The one planned exception: the AX5 ticket must REMOVE the
   existing AX5 skip.
6. Tests and simulator runs use the fake library only. Never touch a real photo library.
7. One ticket in progress at a time. Never invent product decisions or test results.
8. Do not use `Scripts/ticket_controller.py` (PR #37).
9. The five images in `docs/design/orange-porcelain/README.md` are the ONLY approved visual references.

## Never do these (leave them for me)
App Store submission, uploading builds, signing or certificate changes, publishing a version,
anything that costs money, or any change outside this repository.

## Workflow

### Plan in batches (1 Codex step per batch)
At the start of each milestone, write up to 5 small tickets in one go. Each ticket gets: goal,
exact files DeepSeek may change, acceptance criteria, what not to touch, and which checks prove
it. Create them as GitHub issues. Split anything big or vague.

### Each ticket
1. **DeepSeek implements** in a fresh worktree from the ticket text alone. Give it only the
   ticket, `PROJECT-BRIEF.md`, and the files the ticket names. It must:
   - write or update tests for the change;
   - run `git diff --check`, `Scripts/run-kit-tests.sh`, `Scripts/typecheck-ios.sh`, and the
     relevant simulator tests itself;
   - fix its own failures and rerun, up to 5 fix rounds;
   - capture simulator screenshots of any changed screen (light, dark, and the largest
     accessibility text size if layout changed) into `docs/screenshots/milestones/<milestone>/`;
   - finish with a short receipt: files changed, checks run with pass/fail, screenshots taken,
     and anything it is unsure about.
2. **Codex reviews (1 step):** read the receipt, the diff, and only the last 30 lines of any
   failing check output. Never read full logs. Open other files only if the diff raises a real
   question.
   - Good → have DeepSeek open the PR.
   - Not good → send DeepSeek one set of exact corrections. DeepSeek fixes and reruns the checks,
     then Codex reviews again (step 2 of 2).
3. **Wait for CI with one command:** `gh pr checks <PR> --watch --fail-fast`. Do not poll
   repeatedly. If CI fails, DeepSeek fixes it from the failure summary; this counts as its
   correction round.
4. Merge if safety rule 4 allows it. DeepSeek updates the log and `docs/HANDOFF.md`.

**Codex budget:** normally 1 review step per ticket plus a share of the batch plan; at most 2
reviews per ticket. Risky tickets (below) get 1 extra review. If a ticket would need more,
park it.

### When DeepSeek can't finish
If DeepSeek still fails after one correction round, park the ticket: file a `needs-owner` issue
with what went wrong and a suggested smaller split, then move to the next ticket. If the cause
is simply that the ticket was too big, you may split it once into smaller tickets and retry.

### Risky areas: photo deletion, the deletion list, saved sessions, data migration
DeepSeek must add fake-library tests proving that nothing is deleted without the confirmation
step and that saved progress survives. Codex does one extra review focused only on that risky
part. List it under "Risky changes" in the next milestone report.

Agents never remove the `needs-strong-review` label. Under the delegated approval below, the
agent may add `strong-review-passed` and merge only when every condition holds; otherwise only
the owner does. The `strong-review` workflow labels any PR that touches a path in
`.github/risky-paths.txt` and fails until `strong-review-passed` is present.

### Risky PR review rounds (Codex)

This is the standing workflow for any PR labeled `needs-strong-review`.

1. When its checks are green, comment exactly `@codex review` using `gh pr comment`.
2. Wait for Codex's review to appear. Check every 5 minutes with
   `gh pr view <n> --comments`, `gh api repos/Jinshuo7/SWIPR/pulls/<n>/reviews`, and
   `gh api repos/Jinshuo7/SWIPR/issues/<n>/comments`. Give up after 60 minutes and tell the
   owner.
3. If Codex reports problems, fix them in the same PR, push without force, wait for green
   checks, and comment `@codex review` again.
4. If Codex reports problems, fix them in the same PR, push without force, wait for green
   checks, and comment `@codex review` again. Up to 5 rounds per PR.
5. If a **P1** remains after 5 rounds, leave the PR open, add the `owner-blocked` label, and
   move on. Never merge with an open P1.
6. **Delegated approval.** The owner has delegated `strong-review-passed` to the agent. Add it
   and merge (`--match-head-commit`, full SHA) only when ALL hold: checks green on the current
   head; a Codex review of that exact head reports **no P1**; no test, workflow,
   `risky-paths.txt` or gate was removed, skipped, weakened or loosened. P2 findings: fix quick
   ones, otherwise open a follow-up ticket and merge.
7. Never comment `@codex` with anything other than `review`. Only DeepSeek writes code.

### Full autonomy until V1

The owner has delegated approval for the rest of V1 (#26–#36). Work without asking. Stop only
when V1 is code-complete and green on `main`, or when the only work left needs the owner: an
Apple Developer account, App Store Connect, signing, the final icon, a native Chinese review,
or a real-device test. Then open a GitHub issue titled "Owner: V1 ready" (or "Owner: action
needed") that @mentions @Jinshuo7, in plain language. Never sit idle on one PR; if Codex does
not respond, keep working and retry hourly. Flaky tests get a ticket and a root-cause fix;
skipping is never allowed. Hard safety rules still apply (system-confirmed deletion only,
never weaken tests/CI/gate, never force-push, #37 prohibited).

Codex reviews must flag, as blocking: anything that can delete a photo without the explicit
user confirmation step; anything that can add an unmarked photo to, or drop a marked photo
from, the deletion list; anything that can lose or overwrite saved progress, marks, Undo, or
Tumbler state; unsafe save-format migration; and any test that is removed, skipped, loosened,
or otherwise weakened. (Also recorded as "Code Review Rules" in `AGENTS.md`.)

Agents must never weaken the gate. Any PR that changes `.github/workflows/strong-review.yml` or
`.github/risky-paths.txt` must say so at the top of its PR description, because a same-repo PR
runs its own modified copy of that workflow.

### Decisions the docs don't settle
File a `needs-owner` issue with one plain question, your recommended answer, and screenshots if
visual. Skip to work that doesn't depend on it. If everything left depends on parked questions,
use your recommended answers, label the tickets `provisional`, and continue.

### New screens not covered by the approved images
Design them in the Orange & Porcelain style (same colors, type, buttons, light and dark), label
the PR `provisional-design`, and include screenshots.

## Milestone reports (do NOT wait for me afterwards)
After each roadmap milestone, or every 5 merged tickets, DeepSeek drafts and Codex posts (no
rewriting) a GitHub issue labeled `milestone-report`:
```
Milestone: <name>
What the app can now do (plain language):
Screenshots: every main screen, light and dark, inline, next to the matching approved reference
Tickets merged: one sentence each
Risky changes and the tests that cover them:
Provisional designs or decisions to look at later:
Tests or CI changed, and why:
Usage: Codex steps and DeepSeek attempts per ticket, plus DeepSeek cost if Pi reports it
Known problems:
Open needs-owner questions:
```
Then have DeepSeek update `docs/HANDOFF.md` and continue with the next batch.

## Logging
DeepSeek logs every ticket in `docs/IMPLEMENTATION-STATUS.md`: Codex steps, DeepSeek attempts,
DeepSeek fix rounds, corrections, and merged yes/no.

## Stopping and resuming (usage limit, crash, restart)
`docs/HANDOFF.md` must always say: current ticket, branch, state, open PRs, and what is next.
When resuming, read only `docs/HANDOFF.md`, `docs/agents/OWNER-INSTRUCTIONS.md`, and
`PROJECT-BRIEF.md`, then continue. Never redo merged work.

## When the app is done
"Done" means every v1 requirement in issue #24 and `docs/SPEC.md` is built and tested, with
checks green. Open a final `milestone-report` issue titled "Ready for owner release steps", with
full screenshots and a checklist of what only I can do: Chinese review by a fluent speaker,
final icon approval, a real-iPhone test including Live Photos, and App Store submission. Then stop.
