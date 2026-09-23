# UX review: playing SWIPR on the phone

Session: 2026-09-23, iPhone 11 Pro (iOS 26.2.1), build from `main`. Every run
launched with `-uiTestingFakeLibrary`, so no real photo was touched. Full suite at
the time of writing: **211 tests, 0 failures** (130 kit, 31 app, 50 UI).

This is ticket 12's standing instruction: play the finished app the way a person
would, rate it, and report. Ratings are out of 5 and every number has a reason.
Screenshots are committed under [`screenshots/`](screenshots) and were each
inspected by eye; the ones named here are the evidence for each rating.

## What was played

Driven through the device UI suite, in this order:

- **Entry screen** in each reachable state: nothing waiting, a session waiting,
  a session and marks waiting (`entry-01`, `entry-02`, `entry-03`).
- **Choose a photo**: overview, oldest-first, jumped to a month
  (`choose-01`–`choose-03`), grid columns, a marked photo refusing a tap, the
  direction wording (`play-choose-*`).
- **Viewer**: a complete photo of each fixture proportion
  (`viewer-01`–`viewer-04`), the Live Photo badge (`viewer-05`), and both a short
  and a past-threshold drag plus a vertical drag (`drag-01`–`drag-04`).
- **Controls**: the three fixed positions (`controls-bottom`, `-left-column`,
  `-right-column`), close in the top left (`controls-close-top-left`), buttons
  turned off (`play-buttons-off`), and the position surviving a relaunch
  (`play-cluster-after-relaunch`).
- **Moving the controls**: a drag to each slot, a release away from every slot,
  a plain swipe that must not move them, and the photo frame compared across all
  three positions (asserted, and visible in the three `controls-*` shots).
- **Tutorial**: first photo and the largest text size (`tutorial-first-photo`,
  `play-tutorial-ax5`).
- **Review and deletion**: inspection and restore, select mode, restoring to the
  empty state, a cancelled deletion, a confirmed deletion
  (`play-review-select-mode`, `play-review-emptied`, `play-review-ax5`).
- **Statistics**: after two confirmed deletions and at the largest text size
  (`play-statistics-after-deletions`, `play-settings-ax5`).
- **Failures**: a failed save with Retry and with Discard, unreadable saved
  progress, and saved progress from a newer version (`save-failure-retry`,
  `play-discarded-decision`, `play-unreadable-progress`,
  `play-newer-version-progress`).
- **Ends of the rope**: the empty library (`play-home-empty-library`) and a
  Tumbler played to the end.
- **Largest text size (AX5)**: entry, viewer, tutorial, review, result, Choose a
  photo and Settings (`play-*-ax5`).

## Ratings

| Screen / flow | Rating | Why |
| --- | --- | --- |
| Entry screen | 4.5 / 5 | One action, unmistakable. The wordmark, the circle and `Start here` read in the intended order, and the review chip and `Resume` appear without adding a second prominent action. Loses half a point because the wordmark sits vertically centred rather than bottom-weighted, so on a tall screen there is a lot of black above it (`entry-01`). |
| Choose a photo | 4 / 5 | The two traversals answer "where do I start?" before the grid, and month sections plus the jump menu make a large library navigable (`choose-01`). Loses a point for density: explanation, two traversals, jump, order toggle and then the grid is a lot before the first thumbnail. |
| Viewer | 4.5 / 5 | The photo is the content and nothing moves it (`controls-*` show the same frame at all three positions). Swipe feedback is clear and the wells are feedback-only. Loses half a point for the idle fade: after five seconds the controls drop to 55% (`controls-bottom`), which on a bright photo is dimmer than it needs to be. |
| Moving the controls | 4 / 5 | The puck makes the drag's subject obvious and the phantom slots make the destinations knowable; the photo never shifts. Loses a point because at the bottom position the three buttons sit about 29 pt right of centre, since the grip leads the row — the tray is centred, but the eye reads the buttons. |
| Tutorial | 4.5 / 5 | Short, in plain words, and it now teaches the gesture that had no on-screen teaching before (the grip). The symbol-and-word pairs survive a greyscale screenshot. |
| Deleting review | 4 / 5 | The grid, inspection and select-drag restore all work, and the empty state is honest (`play-review-select-mode`, `play-review-emptied`). Loses a point because the header carries three lines of copy at normal size. |
| Result and statistics | 4 / 5 | Only confirmed deletions are counted, and the inline Settings block states lifetime totals at the top with no chevron (`settings-01-inline-statistics`). Loses a point because "≈ 0 bytes" reads awkwardly before anything has been deleted. |
| Largest text size | 4 / 5 | After the fixes below, every screen is reachable and the labels survive (`play-*-ax5`). Loses a point because the fixed header titles are enormous at AX5 and take a large share of the screen. |
| **The flow as a whole** | **4.5 / 5** | Entry → Choose a photo → viewer → review → result is one obvious path with a safety net at the end, and nothing in it is destructive without an explicit confirmation. It is materially less cluttered and less janky than the design it replaces. |

## Fixes made while playing

These were found by looking at the AX5 screenshots. Passing assertions cannot see
truncated glyphs or mid-word breaks, because the accessibility label stays whole
while the drawn text is cut, so the screenshot is the finding and the new
layout assertions are the guard.

1. **Choose a photo truncated its buttons to `Ne…` / `R…` at AX5.** The
   traversals and the jump/order controls now stack vertically at accessibility
   sizes, and the whole chrome scrolls with the grid instead of pushing the jump
   bar off the bottom. Guarded by the new stacking assertion and the scrolling
   reachability assertions in
   `SWIPRUITests/PlaySessionUITests/testPlayEveryScreenAtTheLargestAccessibilityTextSize`.
2. **Settings statistics broke words mid-character at AX5** ("Stor-/age/re-/
   claim/e/d"). The value now stacks under its label at accessibility sizes.
   Guarded by the label-above-value assertion in the same test.
3. **The Choose a photo header title truncated to `Choose…`.** It now wraps
   instead of truncating.

No other defects were found that were common-sense rather than taste.

## Improvements, ranked

1. ~~**Centre the buttons, not the tray, at the bottom position.**~~ **Resolved**
   by moving Undo to the cluster's outer end
   ([ADR-0011](adr/0011-undo-at-the-outer-end.md)): Trash and Keep now sit about
   6 pt from the screen centre at the bottom, where the old layout put them ~29 pt
   off, and Undo is out of the misclick path besides.
2. **Soften the idle fade** (55% → about 70%, or fade later). Cost: trivial.
   Worth it on bright photos where the controls are the fallback.
3. **Say "0 bytes" rather than "≈ 0 bytes" when nothing has been deleted.** Cost:
   trivial.
4. **Cap the header title size at accessibility sizes.** The title is currently
   the single biggest element on several screens. Cost: small.
5. **Consider moving `Resume` next to the chip** so the entry body holds exactly
   one thing. Cost: small, but it is a product decision, listed under
   uncertainties.

## Uncertainties for the owner

These are decisions, not defects. Each says what the owner has to choose.

1. ~~**Button centring at the bottom.**~~ **Decided and done.** Undo moved to
   the cluster's outer end with a two-way left/right setting; Trash and Keep are
   adjacent and effectively centred. See the follow-up section below.
2. **Idle fade.** Keep 55%, or raise it? *Recommendation: raise to ~70%.*
3. **A fuller statistics screen.** The earlier research suggested keeping any
   fuller screen reachable; the current build removed the separate screen and
   inlines everything. Options: (a) inline only (current); (b) inline plus a
   "More" row into the old screen. *Recommendation: (a); the inline block already
   carries every number the old screen did.*
4. **A marks-only entry state.** The spec lists four entry states including
   "marks waiting". In the current product a mark always implies a resumable
   session, so the states are: nothing, session, session+marks. If the owner
   expects to see marks with no resumable session, that is a product rule change
   (`PersistedSession.isResumable`), not a UI fix. *Recommendation: leave as is;
   a mark without a session is not reachable by design.*

## Not covered, and why

- **Real Live Photo playback.** The fake library returns no `PHLivePhoto`, so
  motion cannot be exercised without a device holding a real Live Photo. The
  badge and the spoken description are covered (`viewer-05`).
- **Real deletion against a real library.** Deliberately never done by an
  automated run; the safety invariant forbids it. Confirmed and cancelled
  deletions are covered against the fake.
- **Limited-library access.** The fake always reports full access, so the
  "Select more photos" path is unexercised. It is reachable only in the real
  permission state.
