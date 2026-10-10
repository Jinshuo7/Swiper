# Implementation status

> ## Read this first: two different things share this file
>
> **1. Required production v1** — specified by
> [issue #24](https://github.com/Jinshuo7/SWIPR/issues/24) and the in-repo
> target contract [`SPEC.md`](SPEC.md), delivered by tickets
> [#25–#36](ROADMAP.md). #24 is authoritative. **Almost none of the v1 target
> behaviour below is implemented yet**: ordinary video, Home media choices,
> editable filters, the fixed non-wrapping pool, playback, the neutral whole-dock
> 3-position interaction, Before/After Undo, complete EN/zh-Hans and the App
> Store release work are requirements, not as-built facts. Do not read the
> legacy checkpoint as evidence that any of them exist.
>
> **2. As-built legacy state** — the finished checkpoint below, covering the
> photo-only build from issues #11–#16 (spec #10) and later audit rounds. It is
> real, tested work on the committed history. Its durable safety and persistence
> substance is preserved by v1; its mutable product surface (single-entry flow,
> grip cluster, photo-only scope) is superseded.
>
> **Known status for the v1 baseline:** the former
> largest-accessibility-text ("AX5") reachability failure was fixed by #58, and
> #69 removed its CI skip in PR #72; on that PR's commit the simulator suite ran
> every UI test, including AX5, with 0 failures (`** TEST SUCCEEDED **`). The
> damaged-save-file fix that was open for review is merged as PR #66, and PR #72
> merged too (merge commits `c2af5f5` and `8efd39e`). The one open risky PR left
> is **#74** (marked photos through Limited Photos access, `needs-strong-review`,
> parked `owner-blocked` with issue **#85**); **#70** itself stays open. **PR
> #37** (`Scripts/ticket_controller.py`) remains prohibited: do not use, merge
> or base work on it.
>
> **#46 update (2026-10-02):** the Orange & Porcelain Home and editable filters
> are now wired to the fixed filtered session. The full simulator suite was green
> (276 tests, 0 failures) with the existing AX5 skip still in place at the time
> the branch was produced; #46 was merged as PR #52. Because `SWIPRApp.swift`
> still pins the app to dark (outside #46's file list), `RootView` exposes a
> `-uiTestingForceLight` / `-uiTestingForceDark` screenshot seam; the light
> milestone screenshots use it.
>
> **#47 update (2026-10-02):** the viewer now shows a complete still preview for
> a Photo, Live Photo or Video and names the kind in a neutral
> Live/Video badge in the top bar, centred with Close. A plain photo carries no
> badge. The badge carries a symbol and a word, so its meaning never rests on
> colour. No Play, duration,
> timeline, mute, Retry or Skip ships — that stays with #28. `FakePhotoLibrary`
> gained a test-only launch argument (`-uiTestingMixedMediaLibrary`) that adds a
> photo, a Live Photo and a video on top of the untouched 24-item demo fixture,
> so the all-kinds UI tests and screenshots can reach a video without touching a
> real library. The focused `SWIPRUITests` class is green (43 tests, 0 failures);
> the known AX5 reachability failure in
> `PlaySessionUITests/testPlayEveryScreenAtTheLargestAccessibilityTextSize` is
> unchanged and still skipped in CI. #47 is merged as PR #53 (commit
> `10aa678`).
>
> **#55 update (2026-10-03):** the starting point now offers **Newest first**
> (`choosePhoto.newest`, walks toward older) and **Oldest first**
> (`choosePhoto.oldest`, walks toward newer) as named start actions, alongside
> the untouched **Random** action and a specific-item start from the grid. The
> grid's separate **Newest first / Oldest first** order toggle still reorders
> the months and **Jump to month** still works. `AppModel.startOldest()` pins
> `.newer` the way `startNewest()` pins `.older`, so a named traversal always
> does what its label says and never depends on the saved default direction.
> The focused `SWIPRUITests` class is green (45 tests, 0 failures), adding a
> both-directions start test and a full Oldest-first traversal that reaches the
> visible completion boundary without repeating a photo. The known AX5
> reachability failure in
> `PlaySessionUITests/testPlayEveryScreenAtTheLargestAccessibilityTextSize` is
> unchanged (still fails to scroll `choosePhoto.newest`) and is still skipped in
> CI, left for #58.
>
> **#58 update (2026-10-03):** the AX5 reachability failure in
> `PlaySessionUITests/testPlayEveryScreenAtTheLargestAccessibilityTextSize` is
> fixed. The case was checking **Jump to month** before the controls above it,
> but `assertReachable` only scrolls downward, so the traversal buttons it had
> already scrolled past could never be brought back on screen. At AX5 the
> starting point now checks its controls in the order they appear: explanation,
> **Newest first**, **Oldest first**, **Random**, **Jump to month**, the order
> toggle and a grid cell (`choosePhoto.cell.fake-22`). The view itself is
> unchanged — it already scrolls its chrome with the grid at accessibility
> sizes — and #69 later removed the CI `-skip-testing` line. The AX5 case is
> green (1 test, 0 failures), the rest of `PlaySessionUITests` stays green with
> the skip in place (16 tests, 0 failures), and
> `docs/screenshots/milestones/v1-03-starting-point/choose-photo-ax5.png` shows
> the explanation and both traversal actions whole at AX5.
>
> **#56 update (2026-10-03):** starting a replacement session while an
> unfinished one exists now asks first. `AppModel.requestSession` parks a
> `PendingReplacement` when `resumableSession != nil`, and `ChoosePhotoView`
> shows the new `ReplacementConfirmationView`, which explains that position and
> Undo history are replaced while marked items stay in Review. **Keep current**
> clears the request without writing anything; **Start new** runs the original
> start, which reads — never clears — the durable deletion list, so marks
> survive and the new traversal skips them. `startFrom` still refuses a marked
> item before the confirmation, and a first start (no unfinished session) still
> happens immediately with no confirmation. Focused `SWIPRAppTests` cover Keep
> current (engine, session and store byte-for-byte unchanged), Start new
> (position and Undo replaced, marks and library intact) and the no-session
> case; a focused UI test walks both branches, and
> `docs/screenshots/milestones/v1-03-starting-point/replace-session-light.png` /
> `replace-session-dark.png` show the confirmation. The full simulator suite is
> green (179 kit + 46 app + 64 UI, 0 failures) with the existing AX5 skip in
> place.
>
> **#57 update (2026-10-03):** Random (the Tumbler) is now proved and hardened.
> `TumblerPlan` gained `reserve(_:)`, and `SessionEngine` uses it whenever the
> cursor is placed outside the plan's own `next()` — restoring a session, a
> reconciled recovery, or a direct jump — so the plan can never serve the
> current asset a second time. The persisted plan (`seed`, `remaining`,
> `handled`) and the cursor already round-tripped; the new tests prove the same
> seed and pool always produce the same order, the whole pool is walked without
> repeats (plain, after Undo, after a jump, and after reconciliation), a
> terminated-and-relaunched session resumes the exact saved order and position,
> and reconciliation drops vanished members while crediting no deletion and
> touching no photo. Kit maths: 188 tests, 0 failures. `SWIPRAppTests`: 42
> tests, 0 failures. The AX5 `-skip-testing` line is untouched.
>
> **#81 update (2026-10-07):** the UI suite's launch/terminate handoff is
> deterministic and every UI query is scoped to the collection it looks in. Every #81 report is a launch
> or terminate handoff going wrong: `Failed to terminate
> com.zhangjinshuo.swipr:<pid>: Failed to terminate com.zhangjinshuo.swipr:0`
> from `XCUIApplication.launch()`, a Home that never appeared after a launch, a
> viewer that never appeared after a relaunch, and a Home entry asserted before
> the decision behind it had been saved. All of them now go through the new
> `SWIPRUITests/AppLaunchHandoff.swift`: the app is stopped through the one
> `XCUIApplication` that launched it (a never-launched proxy is what reports the
> `:0`), `tearDown` stops the app and blocks until the system reports it gone,
> `launch(_:firstScreen:)` waits for the foreground screen that launch promises,
> and `beginSession(_:in:)` waits for the grid to hand over to the viewer **or**
> to the replacement confirmation instead of guessing after one second. Entries
> that a decision creates are waited for rather than assumed final, because Close
> returns Home while the decision's save is still in flight. Nothing is skipped,
> shortened, loosened or retried, and
> `testEveryLaunchRunsTheArgumentsItWasGiven` pins the invariant.
>
> **Second reduction: every UI query names its collection.** The suite asked for
> elements with `app.descendants(matching: .any)[identifier]`, which fetches the
> whole accessibility tree and filters it, and that was the query the runner
> timed out on (`Failed to get matching snapshots: Timed out while evaluating UI
> query`). Every lookup is now `app.buttons[…]`, `app.staticTexts[…]`,
> `app.images[…]`, `app.otherElements[…]` or `app.switches[…]`, with the mapping
> read off `app.debugDescription` rather than guessed. Two families are the
> deliberate exception — the viewer canvas and the grid cells, whose element kind
> follows whether their thumbnail has rendered yet — and they are found by
> identifier, which is the state a `waitForExistence` is waiting out.
>
> **Result.** After the second reduction: four consecutive CI runs green (336
> tests each, 0 failures) and three consecutive local full suites green on
> `SWIPR iPhone 11 Pro`. The two stalls recorded before it (a 68 s terminate wait;
> three 30 s snapshot retries) did not recur. The one failure in between,
> `testPlayEntryScreenInEveryState` waiting 30 s for a viewer, stopped when the
> canvas and the cells went back to being found by identifier; whether that was
> the runner stall or only the lookup is not proved, so both readings stay in
> `needs-owner` #84. Nothing was retried, skipped or loosened to get there.
> The reproduction loop and the rules are in `docs/TESTING.md`.
>
> **#76 update (2026-10-08):** the viewer's legacy grip/puck/phantom-slot
> control is replaced by **direct whole-dock movement**, so there is no permanent
> grip and no long press. A drag may begin on any control or in any gap of the
> tray; roughly 9 pt of movement cancels that gesture's pending tap for good and
> morphs the dock into a compact neutral token; the three destination markers are
> drawn in the dock's own shape (never in saturated colour); a valid release
> lands, an invalid one restores the source. `SWIPRKit/DockGeometry` (#75) owns
> the arithmetic and `ControlClusterLayout` lost the grip/slot geometry (its dock
> was 228 × 88 then; **#77** replaced that with the labelled pair at the bottom —
> 286 × 68 — and 56 × 196 columns at the sides). Sharp edge: a
> control's own action fires on the same touch-up that ends a drag, and SwiftUI
> gives no order between the two, so `dockMoved` outlives the gesture by one
> main-queue turn, and a drop back on the destination the dock already occupies
> goes through `AppModel.moveDock(to:)`, which refuses a position that has not
> changed: writing the preferences re-pins the session's direction from the saved
> default, so an unguarded write would silently reverse a walk the user started
> with an explicit "Newest first" or "Oldest first". That is what makes "a move
> never decides" true rather than likely, and it is asserted from every control.
> `DockGeometry.capture` was also corrected to check the destination already
> captured against its release radius before considering a nearer one, so a
> diagonal drag between the bottom row and a side column no longer drops the
> capture early. Taps and swipes are unchanged and are tested at a side position
> too. Full local suite green on
> `SWIPR iPhone 11 Pro`: **225 kit + 50 app + 71 UI = 346 tests, 0 failures**.
> Twelve dock screenshots (bottom/left/right/moving × light/dark/AX5) are in
> `docs/screenshots/milestones/v1-04/`. Delivered and merged as **PR #86**
> (merge commit `2e56f87`), after two Codex rounds: round 1 found the two
> problems named above, both fixed in `9680607`, and round 2 — of that exact
> head — reported no findings.
>
> The dock's labelled/icon chrome and the side layouts stay with **#77**, and the
> persisted preferences (Control Position, Show Buttons, Haptics, Undo Position)
> with **#78**.
>
> **#77 update (2026-10-09):** the dock now has its two neutral layouts. At the
> bottom, Delete and Keep are **labelled pills inside one stadium tray** and Undo
> is a **separate, smaller control** (44 pt) beside them; at a side, all three are
> **separate icon controls** with a 14 pt non-action gap. The labelled pair is the
> anchor in both layouts: `ControlClusterLayout.centre` is the pair's centre at
> every position and `slotRect(for:in:undoSide:)` grows off it by the one control
> and gap the separate Undo adds — to the side it took at the bottom, above it at
> a side — so “Before actions” (Undo left of the bottom pair, above a side pair)
> and “After actions” mirror each other and Delete and Keep never shift under the
> thumb. The chrome is neutral: the red and green buttons are gone, and the only
> red and green left are `DockEdgeTint` rims at 0.16 opacity on a control's own
> edges, at the same strength in every state. The swipe wells wear the same rim
> and nothing else, arming by stroke weight (1 → 3 pt) and the drag's own opacity
> rather than a tinted fill, so no saturation carries a meaning anywhere. The dock
> is a fixed size for a given screen width, never by its content or state, so the
> media still never moves or resizes for chrome (ADR-0006); the one thing a screen
> width changes is the bottom pills' width — 85 pt instead of 104 pt on a 320 pt
> layout, with a 76 pt floor, so the whole dock including Undo stays on screen —
> and the pill labels stop growing at 20 pt rather than truncate, which is what
> the AX5 screenshots show. Full local suite green on
> `SWIPR iPhone 11 Pro`: **229 kit + 50 app + 72 UI = 351 tests, 0 failures**.
> The twelve v1-04 dock screenshots (bottom/left/right/moving × light/dark/AX5)
> were re-captured under `docs/screenshots/milestones/v1-04/`. Delivered and
> merged as **PR #88** (merge commit `7654936`), after five Codex rounds: rounds
> 1–4 found four P2s (comments claiming the pair anchored the side layouts too, a
> well that tinted its whole surface, a bottom dock that clipped Undo by 11 pt on
> a 320 pt layout, and a stale “fixed size” claim in `docs/TESTING.md`), each
> fixed on the PR before the final head, and round 5 on the merged head
> `5da18ea` reported no findings. One CI run on that head failed before any
> assertion with the known `Failed to launch … Timed out while launching
> application via Xcode` stall (#84); the re-run was green, and no retry flag,
> skip or loosened assertion was added.
>
> **#78 update (2026-10-09):** the dock's four choices are one stored struct,
> exposed in Settings, and the optional haptics are one pure contract behind a
> new switch. `ControlPreferences.haptics` (default on) is an **additive,
> backward-compatible** key read with `decodeIfPresent(…, forKey: .haptics) ??
> true`, so a payload written before the setting existed still loads with haptics
> on and nothing is migrated, rewritten or lost. **Undo Position** is now named
> the way `docs/SPEC.md` §5.6 names it — **Before actions** (the default) or
> **After actions**, read relative to the Delete/Keep pair rather than as a screen
> side — while the persisted `undoSide` key and the dock's geometry are
> untouched. `SWIPRKit.HapticFeedback` owns every optional response (nothing on
> pickup, one light on the first capture, nothing while a destination stays
> captured, one soft on a valid landing, nothing on an invalid release or a
> cancelled touch, one light for a swipe past the commit threshold and for a
> press on a control), and `ViewerView.giveHaptic(_:)` is the only place a haptic
> is played, so "Haptics off" cannot be honoured at one call site and missed at
> another. Each Settings choice row announces the current one through its
> accessibility value and the selected trait, so placement never needs a drag and
> VoiceOver says where the dock is. Two Codex rounds: round 1 found a real **P1**
> — `AppModel.updatePreferences` re-pinned the running engine's direction from the
> saved default on *every* preference write, so toggling the new switch would
> have reversed a walk started with an explicit "Newest first"/"Oldest first"
> and saved the reversal; `updatePreferences` now re-pins and writes the session
> only when `preferences.defaultDirection` itself changed (`78d2a92`), with
> `testChangingAControlPreferenceNeverReversesTheRunningSession` failing four
> times when the old unconditional re-pin is restored, and round 2 — of that
> exact head — reported no issues. Full local suite green on `SWIPR iPhone 11
> Pro`: **233 kit + 55 app + 75 UI = 363 tests, 0 failures**. Six v1-04 Settings
> screenshots (controls and Undo position × light/dark/AX5) are under
> `docs/screenshots/milestones/v1-04/`; Settings is still pinned dark, so its
> light capture matches the dark one. One finding is left for #79: at the largest
> text size the Settings rows are taller than the screen and the pre-existing
> "Reset control position" title hyphenates mid-word. Delivered and merged as
> **PR #90** (merge commit `0151bf6`).

---

## Ticket log

| Ticket | Codex steps | DeepSeek attempts | DeepSeek fix rounds | Corrections | Merged |
| --- | --- | --- | --- | --- | --- |
| Setup — DeepSeek + GitHub Actions guardrails | 3 | 2 | — | Yes | Yes (#40) |
| [#41 — Setup: persist owner workflow and compact project brief](https://github.com/Jinshuo7/SWIPR/issues/41) | 2 | 2 | 1 | Yes — compressed PROJECT-BRIEF.md to ≤2 pages; listed open PRs (incl. prohibited #37); expanded log columns | Yes (#42) |
| [#43 — V1-02a: Expose mixed-media metadata through public APIs](https://github.com/Jinshuo7/SWIPR/issues/43) | 2 | 2 | 1 | Yes — added `Codable` to `MediaCategory` (later `MediaFilter`/persisted filter selections need it); added a JSON encode/decode round-trip test for all categories | Yes (#48) |
| [#44 — V1-02b: Filter a mixed-media pool with pure domain logic](https://github.com/Jinshuo7/SWIPR/issues/44) | 1 | 1 | 0 | No | Yes (#49) |
| [#45 — V1-02c: Persist and reconcile the fixed filtered session pool](https://github.com/Jinshuo7/SWIPR/issues/45) | 2 | 1 | 0 | No | Yes (#50) |
| [#46 — V1-02d: Wire Home and editable filters into a fixed session](https://github.com/Jinshuo7/SWIPR/issues/46) | — | 1 | 2 | No | Yes (#52) |
| [#47 — V1-02e: Show mixed-media still previews and neutral kind badges](https://github.com/Jinshuo7/SWIPR/issues/47) | — | 1 | 0 | No | Yes (#53) |
| [#55 — V1-03a: Offer both named traversals and complete without wrapping](https://github.com/Jinshuo7/SWIPR/issues/55) | — | 1 | 0 | No | Yes (#59) |
| [#58 — V1-03d: Make the starting point reachable at the largest text size](https://github.com/Jinshuo7/SWIPR/issues/58) | — | 1 | 1 | No | Yes (#60) |
| [#56 — V1-03b: Replace an unfinished session only after confirmation](https://github.com/Jinshuo7/SWIPR/issues/56) | — | 1 | 3 | No | Yes (#61) |
| [#57 — V1-03c: Keep Random deterministic, repeat-free and reconciled](https://github.com/Jinshuo7/SWIPR/issues/57) | — | 1 | 1 | No | Yes (#62) |
| [#69 — V1-08a: Re-enable the skipped AX5 large-text UI test](https://github.com/Jinshuo7/SWIPR/issues/69) | 3 | 1 | — | Yes — rounds 1–3 asked to refresh `docs/HANDOFF.md`, `docs/IMPLEMENTATION-STATUS.md`, `docs/SPEC.md` and `docs/agents/PROJECT-BRIEF.md` after the skip removal; all are in PR #72 | Yes (#72, `8efd39e`) |
| [#66 — keep a damaged save file instead of replacing it with empty progress](https://github.com/Jinshuo7/SWIPR/pull/66) | 4 | 1 | 4 | Yes — rounds 1–4 found 7 issues in the legacy-save reader (backup reuse, non-resumable fragments, plan/mode consistency, blank plan IDs); all fixed | Yes (#66, `c2af5f5`) |
| [#81 — V1-12a: Stabilise the flaky UI app-termination test](https://github.com/Jinshuo7/SWIPR/issues/81) | — | 1 | 2 | No | Yes (PR #83) |
| [#76 — V1-04b: Wire direct dock movement into the viewer](https://github.com/Jinshuo7/SWIPR/issues/76) | 2 | 1 | 0 | Yes — round 1 found a preference write that could re-pin the session's direction, and a capture dropped inside its own release radius; both fixed in `9680607` with tests verified by breaking the fix, and round 2 reported no findings | Yes (PR #86, `2e56f87`) |
| [#77 — V1-04c: Neutral decision-dock chrome and side layouts](https://github.com/Jinshuo7/SWIPR/issues/77) | 5 | 1 | 4 | Yes — round 1: comments claimed one pair anchor across both layouts while a side column was anchored whole (wording fixed, `8ca20d5`); round 2: that same comment plus an outcome well that tinted its whole surface and strengthened the fill when armed (the pair became the anchor in the side layouts too, and the well tint became a rim at constant strength, `a3b0257`); round 3: the fixed 286 pt bottom dock clipped Undo by 11 pt on a 320 pt layout (fitted pill width, `395916e`); round 4: `docs/TESTING.md` still called that width fixed (wording corrected, `5da18ea`); round 5 on the merged head reported no findings | Yes (PR #88, `7654936`) |
| [#78 — V1-04d: Persist Control Position, Show Buttons, Haptics, Undo Position](https://github.com/Jinshuo7/SWIPR/issues/78) | 2 | 1 | 1 | Yes — round 1 (P1): `AppModel.updatePreferences` re-pinned a running session's direction from the saved default on every preference write, so toggling the new Haptics switch could reverse a walk started with an explicit "Newest first"/"Oldest first" and save it; the re-pin is now conditional on `defaultDirection` itself changing (`78d2a92`, test verified by restoring the old behaviour, which fails it four times); round 2 on that exact head reported no issues | Yes (PR #90, `0151bf6`) |

> **Note:** PR #50 touched saved sessions and migration but merged without `needs-strong-review`; the owner reviewed it afterwards with Codex, and the problems found are being fixed in separate tickets.
>
> **Strong-review note:** the owner approved PR #65 (the strong-review gate) and explicitly told the agent to add the `strong-review-passed` label to that PR so it could merge. Only the owner adds that label; this was a one-time instruction.

---

## Legacy checkpoint (issues #11–#16, photo-only — as-built history)

Final checkpoint for the autonomous implementation of GitHub issues #11–#16
(parent spec #10). Read with `docs/IMPLEMENTATION-PROMPT.md`,
`docs/specs/photo-cleaning-redesign.md` and `docs/TESTING.md`.

## Where this stands — the device block is CLEARED

The iPhone became available, and **the full suite now runs green on it**:

| Target | Tests | Result |
| --- | --- | --- |
| `SWIPRKitTests` | 111 | 0 failures |
| `SWIPRAppTests` | 29 | 0 failures |
| `SWIPRUITests` | 20 | 0 failures |

**160 tests, 0 failures, `** TEST SUCCEEDED **`** on the iPhone 11 Pro
(`00008030-000669DE3408802E`, iOS 26.2.1). Run twice: once at 21:09 and again at
21:32 on the final committed tree, both green. Result bundle
`.derivedData/final.xcresult`.

Nine screenshots were exported and **visually inspected** (not merely generated)
— see "Screenshots inspected" below. Three defects that no test could catch were
found that way and fixed.

Still not verified: real Live Photo playback. The fake library returns no
`PHLivePhoto`, so motion is not exercised by automation and needs a manual check
with a real live photo.

## Commits (local only — nothing pushed)

| Commit | Ticket | Subject |
| --- | --- | --- |
| `c61491f` | #11 | Bound the viewer and show complete photos |
| `86e00bc` | #12 | Persist accepted decisions and surface recovery failures |
| `96abcb2` | #13 | Preserve marked photos across sorting sessions |
| `98a6f36` | #14 | Complete review, deletion recovery and return to sorting |
| `6fe4780` | #15 | Minimal swipe feedback and replayable teaching |
| `57f6ce8` | #16 | Verify and deliver interruption-safe photo cleaning |
| `4867a6f` | — | Fix favourite-effect ordering and a mutation-chain race in AppModel |
| `9a5e22b` | — | Give review thumbnails a spoken label and hint |
| `7422663` | — | Align roadmap vocabulary with the shipped wording |

`git diff --stat 963ee79 HEAD` → ~4.8k insertions across 47 files.

The three commits after #16 come from a follow-up audit of the app paths whose
tests cannot run; see "Follow-up audit" below.

Issue state: #11 closed (its own criterion explicitly allows recording the device
blocker); #12, #13, #14, #15 commented and left **open** because their device
evidence is pending. #16 is commented and left open for the same reason. Parent
#10 and the old backlog #1–#9 were not touched or closed.

## Checks actually run (exact commands and real results)

1. Pure logic, macOS, no device:

   ```
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Scripts/run-kit-tests.sh
   ```

   **111 tests, 0 failures**, exit 0 (baseline before this work: 66).

2. iOS compile check of the framework and the whole app:

   ```
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer Scripts/typecheck-ios.sh
   ```

   **`OK`**, exit 0. The script now passes `-Xfrontend -disable-sandbox` itself.

3. Compiles all three test targets without a device:

   ```
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer TMPDIR=$PWD/.tmp \
   xcodebuild build-for-testing -project SWIPR.xcodeproj -scheme SWIPR \
     -destination 'generic/platform=iOS' -derivedDataPath ./.derivedData \
     -allowProvisioningUpdates \
     OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sandbox'
   ```

   **`** TEST BUILD SUCCEEDED **`**, including `SWIPRAppTests` and
   `SWIPRUITests`.

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
- Therefore not executed: every `SWIPRAppTests` case (durable save/retry,
  restart, migration, unreadable/newer state, cross-session marks, deletion
  recovery, the integrated journey, tutorial state) and every `SWIPRUITests`
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

## Follow-up audit (round 2): two real defects found and fixed

With the device still unavailable, the never-executed app paths were re-read line
by line. Two genuine defects in `AppModel` were found and fixed:

1. **Favorite library effects were no longer serialised.** The rewrite fired
   `.setFavorite` effects from `acknowledge` inside a detached `Task`, after the
   save, with no input blocking — so a favorite followed quickly by Undo could
   reach PhotoKit out of order. The original code had blocked input while a
   favorite write was in flight, and #12 requires input to be serialised. Now
   *all* library effects run inside the serialised chain **before** the save, and
   there is nothing left to perform afterwards, so a retry can only ever retry
   the write. `PendingDecision` no longer carries an effect list at all, which
   removes the "effects replayed on retry" failure mode by construction.
2. **The mutation chain had a race.** `enqueue` wrapped `serialized` in a `Task`,
   so two gestures delivered in the same run-loop turn could both observe an
   empty tail and run concurrently, letting the later save overwrite the earlier
   one. The chain link is now installed synchronously in `chain(_:)` before
   returning.

Also in this round: `Start Here` no longer fires a tap on a marked cell (the cell
explains itself with its MARKED badge), the unused `-uiTestingFailSaves` wiring
and its wrapper store were replaced by a precise
`-uiTestingFailFirstDecisionSave` seam (`InMemorySessionStore.failSaveAttempt`),
and a UI test was added for the visible save-failure banner and its Retry, which
was the one user story with no UI coverage at all.

Also: review-grid thumbnails now carry a real accessibility label
("Marked photo N of M", plus selection state) and a hint, instead of being
unlabelled images that VoiceOver cannot describe.

Checks after the fixes: `Scripts/run-kit-tests.sh` → **111 tests, 0 failures**;
`Scripts/typecheck-ios.sh` → `OK`; `build-for-testing` → `TEST BUILD SUCCEEDED`.
The device block is unchanged, so the new UI test is likewise unexecuted.

## What the device run changed

Three real problems, none of which any amount of local building would have found:

1. **`SWIPRAppTests` was testing a fresh library, not a relaunch.** My
   "relaunch" test built a second `FakePhotoLibrary`, so the deleted photo came
   back and nothing reconciled. Fixed to share the library instance; the
   production behaviour was correct all along.
2. **The mid-gesture drag helper could not work.** `XCUICoordinate.press(...)`
   asserts "Must be called on the main thread", so dragging from a background
   queue threw immediately. `holdDrag` is inverted — drag on the main thread,
   screenshot from a background queue while the drag is held — and now produces
   the drag attachments.
3. **The drag tint washed the whole screen.** Visually inspected screenshots
   showed a brown/red cast over the photo, which is neither "restrained" nor good
   for photo visibility. Now confined to the leading edge (fades out by 38%, capped
   at 0.20); the wells carry the meaning. Also replaced the debug-sounding injected
   error text "test failure" with "Swiper is simulating a full disk.".

A safety hole was closed before the first device run: a unit-test bundle is
hosted *inside* the app process, so the app was constructing the real
`PhotoKitLibrary` and opening the real `FileSessionStore` before any test ran.
The app now treats `XCTestConfigurationFilePath` as a fake-library run.

## Screenshots inspected

All eleven attachments from the green run were looked at:

Committed, resized, under `docs/screenshots/`:

| Screenshot | What it confirmed |
| --- | --- |
| `viewer-01-panorama-complete.png` … `viewer-04-landscape-bright-complete.png` | Complete asset visible, all four edge markers present, black letterboxing, centred, Close/Favorite/Undo on screen — nothing cropped. Covers panorama, square (bright), portrait and landscape (bright) |
| `drag-01-left-below-threshold.png` | Trash well with symbol **and** the words "Mark for deletion", photo following the finger, below-threshold state |
| `drag-02-left-past-threshold-armed.png` | Well armed: larger, thicker bright stroke; tint confined to the leading edge |
| `drag-03-right-below-threshold.png` | Green check well reading "Keep" |
| `drag-04-vertical-no-decision.png` | No well, no tint, photo unmoved |
| `tutorial-swipe-preset.png` | Four instructions with coloured symbols, plus "Nothing is deleted until you review and confirm." and the automatic-saving sentence |
| `settings-how-to-use.png` | Replay entry present |
| `save-failure-retry.png` | "Couldn't save your last decision" banner with Retry and Discard, photo unchanged behind it |

## Round 2 — the control rail (user review, 2026-09-21)

The user reported that the buttons move around depending on the photo, that
Start Here is confusing and unnavigable, that statistics should not sit on the
main screen, and asked for controls movable to the bottom or a side rail. A new
goal tracks that work; this round covers the rail and statistics.

**First, the reported movement was reproduced rather than guessed at.** Two UI
tests were written before any fix:

- `testControlRailDoesNotMoveBetweenPhotos` — **passed**, so the rail was *not*
  drifting with the photo's aspect ratio. That ruled out the obvious theory.
- `testControlRailDoesNotMoveWhenAMarkAppears` — **failed**, printing
  `(196.7, 668.0)` against `(196.7, 702.0)`: the Review bar appearing shoved the
  decision controls **34pt up**. That was a real defect introduced in the #11
  round, where the cluster's bottom padding depended on `queueCount`.

Fixes and changes:

- The chrome container is now **pinned to the screen** (`.frame(width:height:)`
  before the overlays). Previously the ZStack sized itself to the photo, so a
  tall asset could move the chrome.
- **One rail holds every control.** `ControlRail` (Bottom / Left side / Right
  side) × `ControlAnchor` (start / centre / end) replaces the old three-way
  placement. Order is fixed from least to most thumb-accessible — Close,
  Favorite, Undo, Delete, Keep — so on a side rail Close sits at the top and Keep
  at the bottom, exactly as the user described.
- Favorite and Undo previously jumped between the top bar and the cluster
  depending on the preset. They now always live on the rail, so switching preset
  changes which controls exist, never where they are. Verified by
  `testSwitchingPresetDoesNotMoveTheRail`.
- The review entry moved to the **top strip**, so marking a photo can no longer
  displace the decision rail.
- A vertical rail reserves an **88pt lane** and the photo is fitted beside it,
  not underneath it (`testASideRailDoesNotCoverThePhoto`).
- **Statistics moved into Settings**, with `chart.pie` in place of the
  Wi-Fi-looking `chart.bar`, and `testStatisticsIsReachedFromSettings` asserts it
  is gone from the main screen.
- The Settings rail/anchor controls are explicit option rows, not segmented
  pickers: SwiftUI does not expose a segmented `Picker`'s identifier or segment
  labels to XCUITest, which cost two failed runs to discover.
- `ControlPreferences` gained a decoding migration: the legacy `placement`
  left/centre/right is carried over as the rail anchor rather than silently
  resetting the user's choice.

Checks: **170 tests, 0 failures** on the iPhone 11 Pro (115 + 29 + 26),
`TEST SUCCEEDED`. Screenshots refreshed and inspected under `docs/screenshots/`.

All five items of the current goal are addressed: the rail (with order), Start
Here, statistics in Settings, the localisation survey plus its enforcement guard,
and interruption verified on the device.

Genuinely outstanding, and deliberately so:

- The localisation **migration** has not started. `docs/LOCALIZATION.md` says why:
  it is all-or-nothing, it needs the SWIPRKit catalog first, and it needs a
  decision about who supplies the `zh-Hans` translation. This is the largest
  remaining piece of the user's brief ("at least English and Chinese").
- Real **Live Photo playback with a real live photo** was confirmed manually by
  the user, but no automated test covers it: the fake library returns no
  `PHLivePhoto`.
- The default preset is still **Swipe**, which shows no Keep/Delete buttons. The
  user was shown buttons in a preset they had chosen; whether the default should
  change is their call and is flagged in the summary.

## Round 3 — Start Here, interruption, and the localisation survey

**Start Here was rebuilt**, because the user's first two complaints were about it
("very confusing", "just a photo library with no features, no sorting mechanism,
no pick-the-date function, and no way to reach the bottom without scrolling from
the oldest photo"):

- It now states what it is for: choosing where to begin, after which Swiper walks
  toward older photos and skips anything already decided or marked.
- The library is grouped into calendar months with sticky headers and per-month
  counts, newest first by default.
- A "Jump to month" menu scrolls straight to any month, and an order control
  flips newest/oldest. Both are asserted by UI tests.
- `SWIPRKit/LibraryCalendar` holds the grouping and the localised month titles,
  with nine unit tests, including one asserting a Chinese title (`2024年11月`).
- The demo fixtures now spread across months rather than hours, so the grid has
  real sections in tests and screenshots.

**Interruption.** A mark whose photo vanished outside Swiper is now explained on
return instead of silently disappearing, and an app test kills a session mid-flow
and asserts that position, marks and Undo all survive into a fresh model. The
existing mechanics already covered it: a decision is saved before it is
acknowledged, and home offers Continue sorting plus Review & delete · N. No
progress bar was added: `CONTEXT.md` reserves "progress" for confirmed deletion
totals, so inventing one would have contradicted the glossary.

**Localisation: surveyed, not migrated.** `docs/LOCALIZATION.md` inventories ~150
user-facing strings and names the blockers, the most important being that much of
the copy lives in `SWIPRKit` and so needs a framework catalog with
`bundle: .module` lookups. Six places build plurals by hand and must become
catalog plural variations. `Scripts/check_localizations.sh` enforces the
no-half-migrated rule; it was verified to pass a complete catalog, fail an empty
value, accept plural variations, and no-op while no catalog exists. The migration
itself is deliberately not started — it is all-or-nothing, and it needs a decision
about who supplies the `zh-Hans` translation.

The rail also gained a configurable **order** (`Close first` default, or
`Keep first`), which is the second half of the handedness choice: a left thumb on
a bottom rail reaches the near end, so the decisions have to be able to move
there. Without it the left-handed case was only half solved.

Interruption is now verified on the device, not just in unit tests:
`testKillingTheAppMidSessionRestoresPositionMarksAndUndo` sorts, terminates the
app, relaunches it and asserts that home offers Continue sorting, that the mark
survived, that the session resumes at the same photo, and that Undo still
reverses the mark made before the kill.

Checks: **188 tests, 0 failures** on the iPhone 11 Pro (126 + 31 + 31),
`TEST SUCCEEDED`. 20 screenshots committed under `docs/screenshots/`.

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
