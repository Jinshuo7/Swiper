# Design response: quiet utility with a warm editorial edge

Provenance: the designer's written response to `DESIGN-BRIEF.md`, returned
2026-09-24. The SwiftUI implementation from the same response lives on the
`design/quiet-utility` branch.

# SWIPR — UI redesign handoff

## Direction

**Quiet utility with a warm editorial edge.** The photo stays the hero while
the surrounding screens use a soft neutral canvas, deliberate spacing, rounded
surfaces, and one restrained terracotta accent. The interface remains native
SwiftUI, SF Symbols, and the system font; no external assets or dependencies.

Mobbin's photo and gallery UI collections and mobile home-screen collection
were used as pattern references: [Photo](https://mobbin.com/explore/mobile/ui-elements/photo),
[Gallery](https://mobbin.com/explore/mobile/ui-elements/gallery), and
[Home screens](https://mobbin.com/explore/mobile/screens/home). Mobbin returned
only its anti-bot shell to direct page reads in this environment, so the design
uses those collections as pattern categories rather than claiming to reproduce
a particular app or screenshot.

## What changed

- **Entry:** optical focus on a compact photo-stack brand mark, a one-time settle
  animation (static state under Reduce Motion), a short promise, and the existing
  single primary action. Session resume and review remain secondary.
- **Choose a photo:** removed the explanatory paragraph so Newest / Random and
  month navigation lead quickly into the thumbnail grid.
- **Review, Settings, permission, tutorial, and result:** moved from hardcoded
  dark-only surfaces to a semantic adaptive palette and quieter surface/border
  hierarchy.
- **Viewer controls:** Delete and Keep are 64 pt; Undo is visually 46 pt with a
  56 pt hit target. Cluster geometry now matches the larger primary controls.
- **Dock placement:** while dragging, only the currently valid highlighted slot
  is drawn. This replaces the three overlapping ghost trays; the original
  finger-tracked puck and fixed destinations remain.
- **Safety:** the viewer image stage remains black in either appearance so the
  complete photo and its letterboxing continue to read as one presentation.

## Palette

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| Background | `#F4F3F0` | `#111216` | App canvas |
| Surface | `#FFFFFF` | `#1B1C21` | Cards and controls |
| Foreground | `#191A1E` | `#F7F6F3` | Primary text |
| Secondary | `#5D5E65` | `#B9BAC2` | Supporting text |
| Accent | `#B33A30` | `#C44238` | Brand and primary action |
| Delete | `#C63F38` | `#FF766D` | Mark-for-deletion feedback |
| Keep | `#277A56` | `#68D59A` | Keep feedback |

Colors are resolved from the system appearance. Red/green remain paired with
labels and symbols; they are not the only indication of an outcome.

## Integration notes

Add `SWIPRTheme.swift` to the app target. The archive is a source/design handoff,
not a complete Xcode project; the original archive contains no project file or
buildable test workspace. No Apple Swift compiler/SDK is installed in this
Linux sandbox, so visual verification, iOS compilation, and UI tests must run in
the app's Xcode project on macOS. The app entry point should not force
`.preferredColorScheme(.dark)`; remove that override if present in the project
outside the supplied files.
