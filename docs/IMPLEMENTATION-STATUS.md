# Implementation status checkpoint

Final checkpoint for the autonomous implementation of GitHub issues #11–#16
(parent spec #10). Read with `docs/IMPLEMENTATION-PROMPT.md`,
`docs/specs/photo-cleaning-redesign.md` and `docs/TESTING.md`.

## Where this stands

All six tickets are implemented, committed locally and reviewed against their
acceptance criteria. **The only outstanding gap is device execution**: the
connected iPhone reported `unavailable` for the whole session and this machine has
no iOS Simulator runtime, so `SwiperAppTests` and `SwiperUITests` have never run
since the redesign. Nothing that depends on them is reported as passed.

## Commits (local only — nothing pushed)

| Commit | Ticket | Subject |
| --- | --- | --- |
| `c61491f` | #11 | Bound the viewer and show complete photos |
| `86e00bc` | #12 | Persist accepted decisions and surface recovery failures |
| `96abcb2` | #13 | Preserve marked photos across sorting sessions |
| `98a6f36` | #14 | Complete review, deletion recovery and return to sorting |
| `6fe4780` | #15 | Minimal swipe feedback and replayable teaching |
| _(this commit)_ | #16 | Verify and deliver interruption-safe photo cleaning |

`git diff --stat 963ee79 HEAD` → 47 files, ~4.8k insertions.

Issue state: #11 closed (its own criterion explicitly allows recording the device
blocker); #12, #13, #14, #15 commented and left **open** because their device
evidence is pending. #16 is commented and left open for the same reason. Parent
#10 and the old backlog #1–#9 were not touched or closed.

## Checks actually run (exact commands and real results)

1. Pure logic, macOS, no device:

   ```
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Scripts/run-kit-tests.sh
   ```

   **110 tests, 0 failures**, exit 0 (baseline before this work: 66).

2. iOS compile check of the framework and the whole app:

   ```
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Scripts/typecheck-ios.sh
   ```

   **`OK`**, exit 0. The script now passes `-Xfrontend -disable-sandbox` itself.

3. Compiles all three test targets without a device:

   ```
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer TMPDIR=$PWD/.tmp \
   xcodebuild build-for-testing -project Swiper.xcodeproj -scheme Swiper \
     -destination 'generic/platform=iOS' -derivedDataPath ./.derivedData \
     -allowProvisioningUpdates \
     OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox'
   ```

   **`** TEST BUILD SUCCEEDED **`**, including `SwiperAppTests` and
   `SwiperUITests`.

4. The #11 commit was additionally verified in isolation in a clean git worktree
   (`git worktree add … c61491f`), where `Scripts/run-kit-tests.sh` passed, so the
   intermediate commit is self-consistent.

## Blocked checks (NOT passed, NOT claimed)

- `xcodebuild test` on the iPhone `00008030-000669DE3408802E`: **blocked**.
  `xcrun devicectl list devices` reported `unavailable` from 12:17 onward and
  stayed `unavailable` at every re-check (ticket boundaries and the final pass).
  A first attempt while it still reported `booted` hung ~35 minutes with no
  `xcresult` progress and was killed; `ps`/`timeout` are unavailable in this
  sandbox, so the wait was bounded by hand.
- No Simulator fallback exists: `xcrun simctl list runtimes` is empty (the runtime
  was removed for disk), and the prompt forbids reinstalling it.
- Therefore not executed: every `SwiperAppTests` case (durable save/retry,
  restart, migration, unreadable/newer state, cross-session marks, deletion
  recovery, the integrated journey, tutorial state) and every `SwiperUITests`
  case (viewer bounds, drag wells, tutorial, home/review navigation).
- **No screenshot exists.** The UI tests are written to attach them (see the
  table in `docs/TESTING.md`), and mid-gesture shots are captured while the drag
  is held, but none has been produced or visually inspected. The design's
  "inspect screenshots" criteria are unmet.
- **Real Live Photo playback** is unverified and cannot be covered by the fake
  library, which returns no `PHLivePhoto`. It needs a manual device check.

## Decisions worth knowing

- Stored shape is `PersistedState { schemaVersion, marks, session, updatedAt }`,
  schema 2, in the same `session.json`. Legacy unversioned files migrate in
  memory; the old bytes are replaced only after a successful atomic write. See
  `docs/adr/0004`.
- Unreadable and newer-version data block writes until the user explicitly sets
  the unreadable file aside (`quarantineUnreadableState()`), so an update can
  never silently empty someone's list.
- The deletion list outlives sorting sessions; a new session resets traversal,
  in-session decisions and Undo only. See `docs/adr/0005`.
- Decisions are staged on a copy, saved, then acknowledged. A failed save parks a
  `PendingDecision` and offers Retry (persistence only, so no library effect is
  repeated) or Discard. All mutations run on one serial chain.
- Local storage and PhotoKit are not one transaction. Swiper never claims a
  deletion it did not confirm: after a commit it re-reads the library, removes
  only confirmed-deleted assets, keeps unsuccessful ones marked, and reconciles
  vanished marks on the next launch without counting them.
- Overlap with old issue #1 (schema versioning) is implemented as substance but
  its "refuse loudly, invent no UI" constraint is superseded by migration plus
  visible recovery. Old issue #8's ADR requirement is covered by ADR-0004. Neither
  old issue was closed or modified.

## Exact next steps for the next session

1. Reconnect and unlock the iPhone, confirm `xcrun devicectl list devices` shows
   it as available, then run the full suite (command in `docs/TESTING.md`).
2. Fix whatever the run reveals; expect the never-executed UI details (drag-hold
   screenshot timing, the `viewer.tutorial` element type, the `review.cell.0`
   lookup, the `result.done` label) to need adjustment.
3. Export and *visually inspect* the attachments listed in `docs/TESTING.md`, then
   report per-issue results and close #12–#16 if the evidence holds.
4. Perform the manual real-Live-Photo check separately and record it as manual.
5. Do not push. Astra performs the final correctness and screenshot review.
