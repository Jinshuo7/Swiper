# Viewer drag affordances

Research date: 2026-09-25. Scope: meaning of three dots, a compact dock grip,
and neutral media/navigation overlays. Supplements `movable-controls.md`.

## Findings from primary sources

- **Apple explicitly uses an ellipsis for More.** Its WWDC25 design overview
  describes secondary toolbar actions in a More menu represented by an ellipsis.
  It also recommends sparse, meaningful tint and monochrome toolbars to reduce
  noise. This supports removing the orange tint from Review and media labels.
  [Apple design overview](https://developer.apple.com/videos/play/meet-with-apple/201/)
- **IBM Carbon uses an overflow menu for additional options under space
  constraints.** Its reference implementation names the glyph
  `overflow-menu--vertical` and uses it to open a menu.
  [Carbon usage](https://carbondesignsystem.com/components/overflow-menu/usage/),
  [Carbon implementation](https://angular.carbondesignsystem.com/documentation/components/OverflowMenu.html)
- **Atlassian distinguishes a drag handle from a More (…) menu.** Its drag
  guidance uses a dedicated handle; if an entity contains interactive buttons,
  it recommends making only the handle draggable. A handle can also open a menu
  offering the equivalent move actions. This is a web-system precedent, not an
  iOS-specific rule or proof that every user recognizes a handle.
  [Atlassian drag guidance](https://atlassian.design/components/pragmatic-drag-and-drop/design-guidelines)
- **Apple uses a grabber to indicate sheet resizability.** That is evidence for
  a grabber's meaning in sheets, not a prescribed movable-toolbar design.
  [Apple sheet presentation](https://developer.apple.com/videos/play/wwdc2021/10063/)
- **Apple recommends alternatives to dragging and continuous feedback.** Its
  guidance highlights acceptable destinations as the drag reaches them and
  recommends identifying one destination at a time. Applying this to a dock is
  an adaptation of content drag-and-drop guidance.
  [Apple drag and drop](https://developer.apple.com/design/human-interface-guidelines/drag-and-drop)
- **Small-looking controls still need comfortable targets.** Apple's design
  tips recommend at least 44 × 44 points for touch controls and adequate contrast.
  [Apple design tips](https://developer.apple.com/design/tips/)

## Conclusion

The strongest documented convention for a standalone three-dot ellipsis is
More/options, not dragging. Do not claim universal recognition either way. A
small dot-texture grip (for example two columns of three dots) is visually
different from an ellipsis, but its discoverability in this custom dock still
needs testing. A short grabber is another option; it can suggest resizing rather
than relocation because of its sheet context.

## Proposed SWIPR application (design judgment, not platform mandates)

- Keep the photo canvas full-screen and preserve the entire image's aspect
  ratio. Float neutral glass Home and Review controls over it.
- Reserve red and green for Mark and Keep. Review, Undo, grip, destination cue,
  and media labels use adaptive neutral foregrounds. The dock cue must not look
  like the red mark-for-deletion cue.
- Use a tiny grip integrated into the dock instead of a large, separately
  enclosed three-dot button. Prefer a compact dot texture over an ellipsis.
  Tap opens Left / Bottom / Right; drag moves the dock. Provide equivalent
  accessibility actions. A one-time hint can explain this custom interaction.
- Keep Undo visually subordinate while retaining its own comfortable,
  non-overlapping touch region. The same applies to the grip: a tiny glyph
  does not justify a tiny hit target or invisible overlap with Trash/Keep.
- Show only one subtle neutral destination highlight as the dock approaches
  Left, Bottom, or Right; settle it magnetically with restrained feedback.
  Do not show three full-size trays or enlarge the grip dramatically.
- Place a compact neutral glass **LIVE** or **Video · duration** badge beneath
  Home, aligned to its leading edge with a clear gap. Omit an extra colored
  status dot. This separates media information from the Review action on the
  right. Position is a mockup hypothesis, not a guideline requirement.
- If the badge is informational, it needs readable text but not a button-sized
  target. If tapping it starts playback, give it a full touch target and
  accessible action label. Keep timeline seeking separate from image dragging.
- Prototype against bright, dark, and busy photos; portrait and landscape
  media; larger text; Reduce Transparency; and screen-reader navigation.

No implementation or generated mockup is part of this research note.
