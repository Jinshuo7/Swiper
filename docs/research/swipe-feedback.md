# Swipe feedback research

## Question

How should Swiper communicate the result of dragging a full-screen photo left or
right without covering the photo with permanent instructions?

## Findings

Apple describes gestures as direct manipulation and recommends immediate
feedback that helps people predict a gesture's result and understand how far
they must move. Apple also says custom gestures must be discoverable, easy to
learn, and not the only way to perform an important action.

A photo that follows the finger while revealing its prospective outcome aligns
with this guidance. A left/right meaning is not an iOS system convention,
however, so Swiper still needs to teach its meanings and retain a non-gesture
control preset.

For Swiper, the promising pattern is therefore:

- move the photo with the drag;
- progressively reveal distinct left and right outcome regions;
- use both an icon and wording, not color alone;
- make the commit threshold visible and provide immediate feedback when crossed;
- keep button-based control presets available for people who cannot or do not
  want to swipe.

## Agreed direction

The action regions are feedback only, revealed while dragging; they are not
persistent buttons or separate tap targets. The existing button-based preset
remains the alternative. Keep the treatment minimal, intuitive, and visually
restrained. Explore subtle gradients or translucent material, but prioritize
icon contrast and photo visibility. Exact geometry, labels, material, and
threshold feedback remain open for visual evaluation.

## Current implementation evidence

`Swiper/Views/ViewerView.swift` moves the photo with the drag but gives no
outcome-specific visual feedback. A low-opacity sentence at the bottom attempts
to explain all gestures instead. On an iPhone 11 Pro the current photo view
expands to 812 × 812 points inside a 375 × 812-point display, pushing controls
and most of that sentence offscreen.

## Primary source

- Apple, *Human Interface Guidelines — Gestures*: gestures should provide
  immediate predictive feedback; custom gestures should be discoverable,
  straightforward, and not the only way to perform an important action.
  https://developer.apple.com/design/human-interface-guidelines/gestures
