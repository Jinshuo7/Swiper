# Orange & Porcelain — refined mockups

Generated with built-in imagegen; awaiting owner review. Behavior is defined by
[the design decision draft](../2026-09-cleanup-flow.md), not incidental details
in these raster images. [Generation prompts](PROMPTS.md).

- [Setup and Settings](01-setup.png): separates Continue sorting from Review;
  condenses grid navigation and includes Your impact.
- [Viewer v3](02-viewer-v3.png): current neutral-chrome proposal, small LIVE
  capsule beneath Home, dot-texture grip, and one neutral magnetic destination.
  [Prompts](VIEWER-V3-PROMPTS.md). Generated grip dots remain approximate despite
  a correction attempt; prototype must use two columns of three tiny dots.
- [Viewer v2](02-viewer-v2.png): previous full-canvas media, floating navigation, smaller
  dock, quiet Undo, three-dot grip and a single magnetic destination cue.
  This supersedes [the initial viewer board](02-viewer.png).
  [Viewer v2 generation prompts](VIEWER-V2-PROMPTS.md).
- [Review and results](03-review.png): mixed-media review, successful deletion
  celebration, partial success without celebration.

## Visual QA and limits

Viewer v2 inspected and its erroneous trash icon in the docking cue replaced
with neutral dots. It uses a tall portrait asset to illustrate full-canvas use;
landscape and square assets still aspect-fit without cropping and may letterbox.
All chrome overlays the canvas rather than reserving layout space. Exact target
geometry, contrast over varied photos, and magnetic capture require a prototype.
Other screen directions accepted by owner; viewer v2 awaits review.

Initial boards: all three inspected. Initial viewer received one correction for missing
Review access and misplaced drag destinations. The edited image still has
approximate geometry: the dragging preview extends beyond the screen edge and
its Undo/grip imagery is malformed. This is not the intended implementation.
Keep the puck and full destination preview inside safe bounds, show Undo and a
ridged grip, preserve identical photo geometry in all placement states, and
validate movement in a native prototype. Raster layouts are not pixel specs.

Generated copy/icons and dark-mode accent use also need implementation review:
use the agreed semantic palette consistently, replace the decorative impact leaf
with a neutral storage symbol, and preserve existing Settings reset behavior.
English-only boards do not constitute multilingual or accessibility validation.
No app source was changed to create these references.
