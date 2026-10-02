# Windows app dock reference

Inspected 2026-09-26: owner-provided local recording
`/Users/beastmini/Downloads/ScreenRecording_09-26-2026 13-04-56_1.MOV`
(approximately 5.94 seconds). Sampled at six frames per second. Recording was
not copied into the repository; unrelated desktop contents are not design input.

## Visible behavior

- Initially a compact floating toolbar contains magnification, Windows and
  keyboard icons, without a separate visible drag handle.
- Around 2.5 seconds the toolbar becomes a small circular Windows token as it
  moves away from the top; a top-edge destination indicator appears.
- The token moves back toward the top, and the full toolbar reappears.
- Another move near the end again uses a compact token, followed by the toolbar
  at a different horizontal position near the top.

The recording has no touch overlay. Exact touch-down region, hold threshold,
release instant, haptics and gesture arbitration cannot be established from it.
This is evidence for the visual transition, not its hidden implementation.

## Proposed SWIPR adaptation

Use a handle-free glass tray as the primary prototype candidate. Once a movement
gesture is recognized, cancel button activation and collapse the tray into a
small neutral token. Track the finger directly, highlight one eligible destination,
then expand into the horizontal/vertical tray on release. Retain three fixed
positions and return to the original position for invalid drops. Photo gestures
remain separate from tray gestures. Exact movement threshold requires device
testing; do not assume the reference requires a long press.

Keep accessible position actions and Settings as non-drag alternatives. A tiny
three-dot menu is a fallback only if handle-free movement proves difficult to
discover or operate. No nine-dot or six-dot permanent handle is required.
