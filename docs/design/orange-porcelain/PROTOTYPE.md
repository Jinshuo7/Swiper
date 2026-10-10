> **Exploratory prototype — not production UI.** This document and the
> `-viewerDockPrototype` build are a throwaway interaction study. They are **not**
> the production-v1 target in [issue #24](https://github.com/Jinshuo7/SWIPR/issues/24)
> / [`docs/SPEC.md`](../../SPEC.md). Known differences from the target:
> * Default prototype controls are **tinted** red/green and the sockets/links are
>   **cyan**; the target is neutral adaptive glass with only extremely faint
>   desaturated edge colour and no cyan.
> * The prototype draws **no Photo/Live/Video badge** beneath Review; the target
>   requires one.
> * Neutral variants exist behind launch flags, but they have **not** been
>   validated for the complete accessibility contract or the iOS 17 material
>   fallback, and generated screenshots are **not proof of visual approval**.
> * Grip/puck/slot vocabulary below is superseded by direct whole-dock movement.
>
> The dated observations in this file are **historical as-built facts** about the
> prototype, not requirements. The original copy is archived at
> [`docs/history/production-v1-reconciliation/docs/design/orange-porcelain/PROTOTYPE.md`](../../history/production-v1-reconciliation/docs/design/orange-porcelain/PROTOTYPE.md).

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
button tap. The dock becomes a 68 pt lightweight token carried above the finger,
and three circular sockets with concentric energy rings reveal the landing
positions. The nearest socket and a dashed magnetic connection light cyan.
Release at a target to expand the dock; release elsewhere to restore its prior
position. Leaving an acquired target has a 15 pt hysteresis margin to reduce
flicker. The compact segmented glass pill gives most of its area to two tinted
rounded-rectangle Trash/Keep segments; a smaller, subdued Undo segment sits at
the outer end without fake balancing space. Reduce Motion removes magnetic
offset and uses a short non-spring landing. Accessibility actions provide
Keep/Mark/Undo and direct placement without dragging.

Dragging the photo tracks the finger horizontally, adds restrained rotation and
scale, and reveals both a diffuse red/green edge halo and a Delete/Keep label in
the upper third. Ordinary photos have no media badge; a future Live Photo or
video fixture should show only LIVE or VIDEO beneath Review. No status text is
drawn below the dock. Swipe state lives in a separate lightweight view so its
per-frame updates do not invalidate the glass navigation and dock; the halo is a
narrow edge gradient with no full-screen blend pass. The review entry is a
circular trash icon matching Home, with the marked count in a badge.

## Validation

Unsigned and signed Debug builds succeeded. Signed build-for-testing including
the sample asset and all test targets succeeded on 2026-09-26. The prototype
was installed and launched on the connected iPhone 11 Pro on 2026-09-26. The
launcher needed `--` before `-viewerDockPrototype` so Xcode 27's `devicectl`
would pass the flag to the app instead of parsing it as its own `-t` option.
After that fix, `bash Scripts/run-viewer-prototype.sh` completed successfully.

The focused device UI check
`ViewerDockPrototypeTests/testMovingFromTrashDoesNotMakeADecision` verifies that
dragging from the same region that marks on tap makes no extra decision. It
passed on the iPhone on 2026-09-26: 1 test, 0 failures. The trace showed the dock
landed at the right destination while the status remained at 1 sample item
marked. Result bundle:
`.derivedData/Logs/Test/Test-SWIPR-2026.09.26_20-06-59-+0800.xcresult`.

The first device run of the larger token exposed a gesture-lifetime regression:
replacing the dock's root view during collapse cancelled the active drag. Keeping
one stable outer dock while swapping only its contents fixed it; the focused test
then passed. Its screenshot was inspected for the centred action pair, outer Undo,
compact enclosure, protagonist action segments, circular review entry, and
right-side vertical landing.

Manual checks still required: perceived spring/magnet quality, accidental taps,
bright/dark image readability, one-handed side placement, and cancellation.

## Sample asset

`SWIPR/Resources/Assets.xcassets/PrototypeCoast.imageset/coast.png` generated with
built-in imagegen. Prompt: “Photorealistic sample photograph for an iPhone
photo-viewer interaction prototype. Tall portrait 9:19.5 composition: winding
coastal road along Mediterranean cliffs, blue sea, green foliage, distant
mountains, clear sky. Natural daylight, realistic detailed photograph, no text,
no UI, no device, no frame. Compose an attractive complete standalone photograph.”

This ordinary-photo fixture has no badge. LIVE and VIDEO are reserved for media
that needs the distinction and should appear beneath Review.
