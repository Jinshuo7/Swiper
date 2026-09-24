# Design handoff: give SWIPR a visual identity

Generated: 2026-09-23. This brief is for the designer (human or model) taking on
the UI pass. The engineering, behaviour and tests are settled; this is about how
the app looks and feels. Read `docs/SPEC.md` for behaviour and `CONTEXT.md` for
the vocabulary, but the short version is below.

## What SWIPR is

An iPhone app for **clearing photos fast**: one photo fills the screen, and a
swipe or a button decides keep or mark-for-deletion. Nothing is deleted while
swiping; marked photos go to a review screen and are only removed after an
explicit system confirmation. Its whole reason to exist is speed and a quiet
screen, not browsing.

- Target: iOS 17+, SwiftUI, portrait iPhone, **dark UI only** (`.preferredColorScheme(.dark)`).
- Framework module `SWIPRKit` holds the logic; `SWIPR/Views/` holds the UI.
- English only, deliberately (no localisation yet, `docs/LOCALIZATION.md`).
- **No new dependencies.** Pure SwiftUI + SF Symbols + a few UIKit bridges.
- Accessibility is a hard constraint: everything must survive the largest
  Dynamic Type size (AX5), Reduce Motion, and VoiceOver.

## The owner's problem, in their words

> "I am happy with how everything is working, except the UI. By UI, I mean
> entirely. For example, the landing page — the start here — the SWIPR. It is
> minimalistic, but I don't find it refreshing or like, 'Oh hey, this is a
> well-designed little app.' There is nothing that's cool about it. For example,
> on the landing page, the SWIPR title is not even centred well. I don't feel
> like it is centred properly. […] What if we see a little SWIPR icon and there
> is a GIF, what if it moves a little bit? What if it glitches out and then shows
> the app's slogan or its use case? You know, like, 'SWIPR delete fast' […] And
> when I am going in there to choose the photo, I don't feel like it — it is a
> lot of words. I don't like it. […] When we drag the three dots, the three
> sections are overlapping. That's not very pleasing to look at. […] I don't need
> the redo or undo button that much. Why don't we make it smaller and the trash
> icon and the check icon bigger?"

## The concrete asks

1. **Landing (entry) screen needs a pulse.** Today it is a wordmark, one white
   circle and the label "Start here". Give it a **logo mark** and a small piece of
   **motion** (a nudge, a glitch, a settle) that resolves into the app's one-line
   promise — working title *"Delete fast."* — then rests. It must not loop
   aggressively, must respect Reduce Motion (a cross-fade or static end state),
   and must not delay the `Start here` action.
2. **The hero group is not centred where the eye expects.** The wordmark + circle
   are centred in the space *below* the header, so they sit low; the wordmark's
   letterforms make it read off-centre too. See `entry-01..03` in the contact
   sheet.
3. **Choose a photo is wordy.** The explanation paragraph plus two traversals
   plus a month jump plus an order toggle is a lot before the first thumbnail.
   Say less; keep `Newest` / `Random` and the month jump findable.
4. **The move gesture's phantom slots overlap.** While the grip is dragged, all
   three candidate trays are drawn at once and the bottom row and the side
   columns overlap in the lower corners into a messy U. Evidence:
   `docs/screenshots/design-slots-mid-drag.png`. Redesign how destinations are
   shown (or which are shown) so the state reads as clean and deliberate.
5. **Icon hierarchy in the cluster is wrong for the product.** Trash (delete)
   and Check (keep) are the primary actions and should read bigger/stronger;
   Undo is occasional and should read smaller/quieter. Today all three are equal
   56 pt circles. The cluster is `[Undo][Trash][Keep][grip]` (Undo can be moved
   to either outer end).

## The assets

Everything is in the repo; no live link needed.

- **`docs/screenshots/`** — 43 PNGs at a 900 px long side, every screen and state,
  named by prefix: `entry-*`, `choose-*`, `viewer-*`, `drag-*`, `controls-*`,
  `settings-*`, `tutorial-*`, `play-*` (the play suite covers failures, empty
  library, review, statistics, and all seven screens at AX5), plus
  `design-slots-mid-drag.png`.
- **`docs/design/contact-sheet-1..3.png`** — the same images tiled with labels, for
  a quick overview.
- **The source** — `SWIPR/Views/*.swift`. The visual vocabulary is small:
  `CircleControl` (the round controls), `PrimaryButtonStyle` / `SecondaryButtonStyle`,
  `WellBackground` (the swipe feedback wells), `PersistenceBanner`, and the
  screen views. `SWIPRKit/ControlClusterLayout.swift`-equivalent geometry lives in
  `SWIPRKit/ControlPreferences.swift` (tray is 286×88, three fixed positions).

### How to see the UI, and what is missing

- **Static screens** are covered by the committed screenshots and the contact
  sheets — that is enough to review layout, type and colour.
- **Motion states** do not photograph well. The two that matter are captured as
  stills: the drag wells (`drag-02-left-past-threshold-armed.png`) and the
  phantom slots (`design-slots-mid-drag.png`). If the designer needs more, we can
  capture any held-gesture frame from the device with the existing UI-test helper,
  and we can describe the timings from `docs/SPEC.md` §5 and
  `docs/research/entry-and-dock-design.md`.
- There is **no Simulator runtime on this Mac**, so there is no shareable running
  build; the phone build is on a personal team.

## Constraints the design must live inside

- **Dark only**, black background; contrast at least 4.5:1.
- **Safe areas**: the bottom row sits 20 pt above the bottom safe edge; side
  columns centre at 75% of the safe-area height. The photo is fitted to the full
  safe area and **never resizes or shifts** for chrome (ADR-0006). Controls float
  over the photo as translucent material.
- The cluster has a **grip at the end opposite Undo**; moving it is by drag, with
  the three fixed positions as slots. See ADR-0007 and ADR-0011.
- **AX5**: buttons and rows must survive the largest text; several screens already
  switch layout at accessibility sizes.
- **Reduce Motion**: no essential meaning may rest on motion.
- Every user-facing string is English; keep new copy short.

## What we need from the designer

Answer these and we will prepare the rest:

1. **What do you need from us?** Specifically: which screenshots/sizes, the
   SwiftUI source, a written style guide, or a set of redlines? Do you want a
   light-mode exploration even though the app ships dark?
2. **Do you produce code, or a spec we implement?** If you hand back SwiftUI,
   great; if you hand back mockups, say which format resolves best.
3. **Brand direction.** Is there a logo mark concept, a typeface preference
   (system font vs a custom wordmark), and one accent colour? Today the only
   colour is the red/green semantic pair and system blue.
4. **The landing line.** Confirm or replace the working slogan ("Delete fast.")
   and say whether it also wants a sub-line ("Swipe to keep. Tap to delete.").
5. **The logo motion.** What is it, how long, and what is the static end state?
   Give us the Reduce Motion fallback.
6. **The slot overlap fix.** Your preferred model for showing the three
   destinations: one at a time, a compact direction indicator, slots only for the
   axis you are heading toward, or something else.
7. **Cluster icon sizes.** A concrete hierarchy for Trash / Check / Undo (and
   whether the grip stays three dots).

## Decisions the owner still has to make

- The slogan wording and whether it appears on the entry screen only.
- Whether to introduce a custom typeface at all (system font is the safe default).
- Whether the accent colour should change from system white/blue.
- How much motion is acceptable on first launch.
