# Native viewer interaction prototype

Branch: `codex/viewer-dock-prototype`. Throwaway debug-only viewer selected by
`-viewerDockPrototype`. Normal launch keeps the production flow. The prototype
uses bundled imagery, fake library wiring and in-memory state, never PhotoKit or
saved cleanup state. It installs using the existing SWIPR bundle identity.

Run with a connected unlocked iPhone:

```sh
bash Scripts/run-viewer-prototype.sh
```

Home opens prototype tuning. Change magnetic capture range (default 85 pt),
maximum attraction (12 pt), haptics, position, or the 4:3 edge-check fixture.
Review shows only sample counts. Keep/Mark append sample decisions; Undo removes
the most recent decision. The sample image stays the same deliberately: this
prototype checks dock interaction, not traversal or playback.

Drag anywhere on the dock. Movement of 9 pt latches movement and cancels the
button tap. The dock becomes a token, three quiet edge markers reveal positions,
and the active target strengthens. Release at a target to expand the dock;
release elsewhere to restore its prior position. Leaving an acquired target has
a 15 pt hysteresis margin to reduce flicker. Reduce Motion removes magnetic
offset and uses a short non-spring landing. Accessibility actions provide
Keep/Mark/Undo and direct placement without dragging.

## Validation

Unsigned and signed Debug builds succeeded. Signed build-for-testing including
the sample asset and all test targets succeeded on 2026-09-26. Device execution
is pending the owner's unlock confirmation; no runtime/device pass is claimed.
The focused UI check
`ViewerDockPrototypeTests/testMovingFromTrashDoesNotMakeADecision` verifies that
dragging from the same region that marks on tap makes no extra decision.

Manual checks still required: perceived spring/magnet quality, accidental taps,
bright/dark image readability, one-handed side placement, and cancellation.

## Sample asset

`SWIPR/Resources/Assets.xcassets/PrototypeCoast.imageset/coast.png` generated with
built-in imagegen. Prompt: “Photorealistic sample photograph for an iPhone
photo-viewer interaction prototype. Tall portrait 9:19.5 composition: winding
coastal road along Mediterranean cliffs, blue sea, green foliage, distant
mountains, clear sky. Natural daylight, realistic detailed photograph, no text,
no UI, no device, no frame. Compose an attractive complete standalone photograph.”

The informational badge says PHOTO because this fixture has no Live Photo/video
data. Its position beneath Review is the proposed position for all media badges.
