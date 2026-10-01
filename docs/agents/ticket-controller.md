# Ticket controller

`Scripts/ticket_controller.py` is the deterministic boundary between an approved
ticket and model work. It runs one ticket and then stops. Codex Desktop starts the
run and reads the compact receipt; it does not poll or supervise the run.

## Control flow

1. Capture HEAD, staged and unstaged patches, untracked-file hashes, relevant
   file hashes, and an optional account-usage snapshot.
2. Reconstruct that exact state in a detached temporary Git worktree. The owner
   checkout is never reset, cleaned, committed, or used as a worker workspace.
3. Validate required visual references. A missing approved reference blocks the
   run; superseded images are never substituted.
4. Classify planning and independent-review risk from manifest flags. Routine
   tickets skip planning. Production acceptance is always a Codex gate.
5. Build a bounded packet and a separate model workspace. The Context Broker
   copies only named files. A model can return `REQUEST_CONTEXT`; read access is
   bounded, while edit-scope expansion blocks for owner approval.
6. Give DeepSeek one session and at most two implementation attempts. The
   controller, not a model, runs the declared checks and content-addresses
   reusable passing evidence.
7. Give Codex the ticket, receipt, diff, evidence, and risks. Codex returns one
   of `ACCEPT`, `CORRECT`, `BLOCK`, or `REQUEST_CONTEXT`. A selective independent
   verifier runs once on the final candidate when risk flags require it.
8. Write `ledger.json`, `receipt.json`, and (only after acceptance)
   `candidate.patch`. Stop. Applying the patch is a separate explicit command.

The normal successful path is DeepSeek implementation, deterministic
verification, and one Codex acceptance call. Planning adds one Codex call; a
single correction adds one more. The controller blocks before a fourth Codex
call, a third worker attempt, an unexpected write, a timeout, or a budget breach.

## Commands

Safe preparation only (the default; invokes no model):

```sh
python3 Scripts/ticket_controller.py run docs/agents/tickets/production-v1-25.json
```

To inspect a different checkout, including an existing dirty owner checkout:

```sh
python3 Scripts/ticket_controller.py run MANIFEST --source-root /absolute/repository
```

Model execution must be explicitly requested:

```sh
python3 Scripts/ticket_controller.py run MANIFEST --execute-models
```

After a run reaches `PATCH_READY`, revalidate the live HEAD and changed-file
hashes and apply only its accepted patch:

```sh
python3 Scripts/ticket_controller.py apply .tmp/agent-runs/RUN/ledger.json
```

Runs and test evidence live under ignored `.tmp/`. Temporary worktrees are kept
for audit and manual inspection. Remove one only after its receipt is no longer
needed, using the owning repository's normal `git worktree remove` command.

## Manifest rules

Paths are repository-relative and exact. `allow_edit` covers existing writable
files; `allow_create` covers named new files. Binary context must also appear in
`allow_binary_context`; that explicit listing is the approval to supply an exact
full-resolution asset when a bounded crop is not available. Required visual references are validated before any
model call. Approximately 25,000 input tokens is a soft packet target: the
controller records an overage and blocks at the explicit byte limit rather than
silently truncating correctness-critical context.

Verification reuse is allowed only for a prior passing result with the same
command, environment, declared input hashes, and tool-version output. The
manifest author must list every relevant input; omission is a review error, not
permission to skip testing.

The ledger records model/call limits, token and cost fields reported by Pi,
attempts, context requests, elapsed time, file access, changed paths, verification
evidence, and final state. Escaped defects and post-acceptance regressions are
later quality annotations; they cannot be known during the ticket run.
