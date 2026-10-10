# Project brief — SWIPR production v1

> Authoritative sources: [issue #24](https://github.com/Jinshuo7/SWIPR/issues/24) → [`docs/SPEC.md`](../SPEC.md) → [`docs/ROADMAP.md`](../ROADMAP.md) →
> [`docs/design/orange-porcelain/README.md`](../design/orange-porcelain/README.md).

## What v1 is

SWIPR is an offline iOS 17+ photo **and video** cleanup app: walk a fixed, filtered pool one item
  at a time, mark for deletion or keep, review, commit via the system confirmation only. No
  accounts, tracking, ads, or uploads; free. English **and Simplified Chinese** ship complete.

## v1 requirements (condensed from #24 / SPEC.md)

1. **Access & privacy** — explain read-write access before asking; support limited access
  (**Select More Photos**); on denial, route to Settings without showing the library.
2. **Home & filters** — Orange & Porcelain home; Settings and Review mirrored top corners;
  **Everything / Photos / Videos**; conditional **Continue sorting**, **Review marked items**,
  quiet **Your impact**. Categories: **Screenshots, Live Photos, Panoramas, Other Photos, Videos**
  (Everything = all + videos; Photos = all; Videos = video). Rows toggle; **Only** isolates;
  exclusions win; items appear once with a pool summary; **Continue** disabled when none selected.
3. **Starting point & pool** — month-grouped grid with month nav; **Newest first / Oldest first**
  or tap an item; **Random** = persisted deterministic repeat-free Tumbler order; traversal
  completes, never wraps; a session captures a **fixed set of stable identifiers**, reconciling
  missing ones; browsing never disturbs it; replacing a session confirms position and Undo are
  replaced while marks remain.
4. **Viewer** — complete asset at original aspect ratio, centred, letterboxed, never cropped/moved
  by chrome; neutral glass overlays in safe areas; small **Photo / Live / Video** badge beneath
  Review; red/green only as faint edge light; swipe always available (left past threshold =
  delete, right = keep); below-threshold/vertical/cancelled drags decide nothing; **Undo**
  reverses only the most recent decision, never deletes.
5. **Decision dock** — three fixed destinations (left, bottom centre, right); bottom = **Delete /
  Keep** pair + smaller Undo; sides = icon controls with a non-action gap; whole dock directly
  draggable (no grip); ~9 pt move cancels the tap and morphs it into a compact token; position
  persisted immediately (Settings: **Control Position**); Undo = **Before actions** (default) /
  **After actions**; Delete and Keep never swap; **Haptics** preference; swipe stays when buttons
  hidden.
6. **Video** — still preview + duration + Play (never auto-play); starts muted, explicit sound
  control, mute per sorting visit only; timeline seeks without moving media; Keep/Delete
  available; sorting drag pauses playback (cancel resumes only if playing, commit stops +
  advances); Undo/resume return paused; playback position per app visit, not durable; unusable
  previews offer **Retry** and **Skip** (Skip records neither).
7. **Deletion review & commit** — one durable deletion list (photos + videos) outliving sessions
  and relaunches; review from Home and viewer (kind + duration thumbnails, individual/batch
  **Restore**); restoring removes from list, keeps for current session; no statistics during
  review; **Delete** = final action, no app confirmation (only the system prompt); deletion only
  from review after system confirmation; sorting never mutates the library; re-read after commit
  counts only confirmed deletions; full success = no-sound fireworks + confirmed count +
  **estimated** storage freed; statistics in Settings + quiet Home **Your impact**.
8. **Persistence** — position, filters, order, decisions, Tumbler order and Undo restored so
  **Continue sorting** is truthful; acknowledged decisions saved before advancing, visible
  retryable **PendingDecision** on failed save; schema-versioned atomic migration;
  unreadable/newer data reported, never overwritten as if empty; only stable identifiers + logical
  session state persisted — never media data.
9. **Appearance & accessibility** — System / Light / Dark; prefer Liquid Glass with iOS 17
  opaque/material fallback of identical geometry; ≥44 pt targets, no colour-only meaning, Dynamic
  Type, VoiceOver labels/hints, placement actions, Voice Control names, Reduce
  Motion/Transparency, contrast, safe areas; English and Simplified Chinese complete (fluent human
  reviews zh-Hans); the AX5 largest-text reachability failure is fixed (#58/#69) and the suite,
  including AX5, must stay green on the release candidate.
10. **App Store release** — name **SWIPR**, subtitle "Clean photos and videos", Photo & Video
  category, free; minimal Orange & Porcelain icon, no text (owner approves final render);
  localized metadata + five screenshots; bilingual privacy policy + support page; "no data
  collected" only after auditing; validate iOS 17 fallback + latest iOS; distribution archive +
  TestFlight; release manually after App Review from the exact tested release-candidate commit.
**Safety invariants** — never delete while sorting; deletion = final review Delete action + system
  confirmation (never a third); a marked item is reversible until commit; an acknowledged decision
  is saved first; statistics reflect only confirmed successful changes; automated tests never
  touch a real photo library.
## Roadmap order (tickets #25–#36)
#25 V1-01 Make the production-v1 contract durable → #27 V1-02 Start a filtered mixed-media session
  → #29 V1-03 Choose a starting point and replace sessions safely → #26 V1-04 Ship the neutral
  direct-move decision dock → #28 V1-05 Play and sort ordinary videos → #30 V1-06 Review and
  delete mixed media safely → #31 V1-07 Celebrate confirmed cleanup and show impact → #32 V1-08
  Make the complete journey accessible and adaptive → #33 V1-09 Ship complete English and
  Simplified Chinese experiences → #35 V1-10 Prove on-device privacy and publish support materials
  → #34 V1-11 Prepare the localized App Store identity and listing → #36 V1-12 Validate and
  deliver the release candidate. Ticket titles are the source of truth.
## Approved visual references (the only five)
Owner-approved five-frame Orange & Porcelain baseline, indexed by
  [`docs/design/orange-porcelain/README.md`](../design/orange-porcelain/README.md). **No other
  image is an implementation target.**
| Role | File | Notes |
| --- | --- | --- |
| Setup / filter direction | `01-setup.png` | 1536×1024 |
| Review direction | `03-review.png` | 1536×1024 |
| Neutral viewer — **bottom** dock | `04-viewer-bottom-neutral.png` | 1125×2436; text labels |
| Neutral viewer — **left** dock | `05-viewer-left-neutral.png` | 1125×2436; icon-only |
| Neutral viewer — **right** dock | `06-viewer-right-neutral.png` | 1125×2436; icon-only |
Bottom dock shows text labels; sides icon-only. The Photo/Live/Video badge beneath Review is
  required though not shown; `02-viewer*.png` and the generation prompts are superseded, not
  targets; new screens follow the same style, labelled `provisional-design`.
