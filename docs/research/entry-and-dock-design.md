# Entry screen and docked controls design

## Question

The entry screen is to become a wordmark, at most two buttons (one a large circular "Start here" action), no explanatory footer, with statistics moved
into Settings as a read-only inline section at the top. The viewer's control cluster is to lose its free docked drag and gain three fixed positions (a
bottom-centre row, and columns centred in the middle of the lower half at the left and right edges), a three-dot grip, a small free-moving circle the
finger carries, phantom slots showing the three positions with the nearest highlighted, and no change on release elsewhere. The owner calls the
current drag janky. This note records what Apple's guidance and API documentation do and do not settle.

## Findings

### Minimal single-action entry screens

Onboarding asks for a first run that is "fast, optional, and not a prerequisite for using the app"; Launching wants launch "straightforward,
uncluttered" and allows a splash screen for branding only. Neither page prescribes a layout, a button count, or a wordmark.
https://developer.apple.com/design/human-interface-guidelines/onboarding and
https://developer.apple.com/design/human-interface-guidelines/launching

The applicable rules sit elsewhere. Buttons: "Keep the number of prominent buttons to one or two per view" and "Use style, not size, to visually
distinguish the preferred choice". iOS: limit "the number of onscreen controls while making secondary details and actions discoverable with minimal
interaction", and reach is best in "the middle or bottom area of the display". Layout: respect safe areas and "differentiate controls from content".
https://developer.apple.com/design/human-interface-guidelines/buttons ,
https://developer.apple.com/design/human-interface-guidelines/designing-for-ios ,
https://developer.apple.com/design/human-interface-guidelines/layout

Type sizes are numeric: the iOS table gives Large Title 44 pt with 52 pt leading, Title 1 38 pt, Body 17 pt, and calls text styles "a typographic
hierarchy you can use to express the different levels of importance in your content". Dark Mode gives direction, not geometry: "dimmer background
colors and brighter foreground colors", base and elevated backgrounds, and a contrast ratio "no lower than 4.5:1" (7:1 for custom colours).
https://developer.apple.com/design/human-interface-guidelines/typography and https://developer.apple.com/design/human-interface-guidelines/dark-mode

Observation, not documentation: Apple's near-empty dark screens carry almost no chrome (Camera: black viewfinder, shutter bottom centre; Fitness and
Journal: one prominent action under a compact title). No Apple page documents their spacing, sizes or button counts.

### Large circular primary buttons

The HIG publishes a hit region, not an iOS size table: "a button needs a hit region of at least 44x44 pt". Accessibility confirms the iOS default is
44x44 pt, the minimum 28x28 pt, and about 12 points of padding around bezelled elements.
https://developer.apple.com/design/human-interface-guidelines/buttons and https://developer.apple.com/design/human-interface-guidelines/accessibility

Shape is discussed only for visionOS: "an icon-only button uses a circle shape", "In general, prefer circular or capsule-shape buttons" because
"People's eyes tend to be drawn toward the corners in a shape". The iOS section covers only activity indicators inside buttons, so iOS states no shape
preference. https://developer.apple.com/design/human-interface-guidelines/buttons A button must "clearly communicate its purpose" with a symbol, text,
or both; a text label should "start with a verb"; a custom button needs a press state or it "can feel unresponsive". A large circle cuts against "use
style, not size", worth knowing rather than a barrier.

Observation, not documentation: the Camera shutter is the clearest first-party large circular action. No Apple page states its diameter, label
treatment, or disabled appearance.

### Signalling that something is draggable

The HIG's grabber definition is on the Sheets page: a grabber "shows people that they can drag the sheet to resize it; they can also tap it to cycle
through the detents", and it "works with VoiceOver". The page documents no general-purpose in-content drag handle.
https://developer.apple.com/design/human-interface-guidelines/sheets
Designing Fluid Interfaces states the general principle: "for sliding panes of content, you can use an affordance, or a grabber handle like this, to
indicate that it's grabbable and slidable", and "if you have an interactive element, lifting it up to a separate plane can help distinguish it from
the content" (the switch knob), because that "helps visually separate it, and indicate its draggable nature". The session also says a gesture
interface "is not immediately obvious", so teaching is part of the design, and a discrete animation aligned with a gesture can teach the gesture.
https://developer.apple.com/videos/play/wwdc2018/803/

Apple's drag-entry patterns are in user guides, not the HIG. Home Screen: touch and hold until "the items begin to jiggle", then "Drag the app or
widget". iPad Stage Manager: "To resize an app window, drag from either of the bottom corners". AssistiveTouch: "To move the AssistiveTouch menu
button, drag it to a new location on the screen", with Idle Opacity to dim it; snapping, persistence and reset are undocumented.
https://support.apple.com/guide/iphone/move-apps-and-widgets-on-the-home-screen-iphd2fc8ce30/ios , https://support.apple.com/guide/ipad/customize-your-workspace-ipadaf1d4cc9/ipados , https://support.apple.com/guide/iphone/use-assistivetouch-iph96b21954/ios
Third party, not Apple: Steam Link puts movement in an edit mode entered from a `[...]` button, where "Select **Edit Layout** to move/scale/remove
existing controls", touching and dragging places a control, and controls "snap into default positions".
https://help.steampowered.com/en/faqs/view/0265-BEF0-5EFF-60DF

### Dragging into phantom slots

The HIG Drag and drop page covers most of this: "Display a drag image as soon as people drag a selection about three points", ideally "a translucent
representation of the content people are dragging", because translucency "helps distinguish the representation from the original content and lets
people see destinations as they pass over them"; "highlight a containing view only when the destination can accept a dragged item ... when it can't",
removing the cue when the content moves away; "When there are multiple possible destinations, provide visual cues that help people identify one at a
time"; on failure "the item can move back from its current location to its source"; "Prefer letting people undo a drag-and-drop operation"; for
transfers, "display a placeholder at the drop location".
https://developer.apple.com/design/human-interface-guidelines/drag-and-drop On keeping the original visible the page describes outcomes: in a same-container move "the content disappears from its
original location when the drag operation performs a move"; a copy leaves the original. The in-flight rule is implied by "distinguish the
representation from the original content"; I verified no Files-specific behaviour beyond that sentence. Phantom slot grids are a game-inventory
convention, not an Apple pattern: no Apple page describes candidate destinations that exist before a drop.

### What makes a drag feel smooth on iOS

Designing Fluid Interfaces (WWDC 2018) is the canonical statement. Response: "our tools depend on the latency ... If you introduce any amount of lag,
things all of a sudden just kind of fall off a cliff", and "look for delays everywhere ... every interaction with the object." Interruptibility: "we
want to allow for constant redirection and interruption", so "the thought and gesture happen in parallel". Direct manipulation: "touch and content
should move together. One-to-one tracking is extremely important. When swiping or dragging, the contents should stay attached to the gesture", and
"the moment the touch and content stop tracking one-to-one, we immediately notice it." Spatial consistency: "it's important to maintain spatial
consistency throughout movement". Hinting: "hint in the direction of the gesture", as Control Center modules "grow up and out towards your finger in
the direction of the final state". Momentum projection: "instead of finding the nearest endpoint to the PIP when I throw, we can calculate its
projected position and move there instead", mixing throw velocity with a deceleration rate.
https://developer.apple.com/videos/play/wwdc2018/803/
Motion HIG: "Add motion purposefully", "Aim for brevity and precision in feedback animations", "Let people cancel motion" and do not make them "wait
for an animation to complete", "generally avoid adding motion to UI interactions that occur frequently", and make feedback motion "follow people's
gestures and expectations". No duration in milliseconds.
https://developer.apple.com/design/human-interface-guidelines/motion

Springs are in the API reference. `spring(response:dampingFraction:blendDuration:)` is "a persistent spring animation ... preserving velocity from one
animation to the next"; `response` is "the stiffness of the spring, defined as an approximate duration in seconds. A value of zero requests an
infinitely-stiff spring, suitable for driving interactive animations"; defaults 0.5 / 0.825 / 0. `interactiveSpring` is "a convenience for a spring
animation with a lower response value, intended for driving interactive animations", defaults 0.15 / 0.86 / 0.25.
https://developer.apple.com/documentation/swiftui/animation/spring(response:dampingfraction:blendduration:) and https://developer.apple.com/documentation/swiftui/animation/interactivespring(response:dampingfraction:blendduration:)
WWDC 2023 Animate with springs updates the vocabulary: Apple configures springs with `duration` and `bounce`, adopted "universally across Apple's
design and engineering efforts". Springs suit the end of a gesture because "a spring can start with any initial velocity, so we get a natural feeling
where our animation picks up right where the gesture ends", and "SwiftUI will now automatically track velocities any time a gesture is changing
properties". On values: pick a duration whose pacing you like, then add bounce; bounce 0 is "a great general purpose spring that's the most
versatile", about 15% "doesn't feel very bouncy yet", and be "cautious about using values higher than around 0.4, since they may feel too exaggerated
for a UI element". Settling duration is unpredictable and "you shouldn't wait for the settling duration for user-facing changes".
https://developer.apple.com/videos/play/wwdc2023/10158/

`matchedGeometryEffect` "defines a group of views with synchronized geometry using an identifier and namespace that you provide", taking geometry from
the view where `isSource` is true. The reference does not say when to reach for it; it is the API for one item appearing to move between two places
instead of being rebuilt.
https://developer.apple.com/documentation/swiftui/view/matchedgeometryeffect(id:in:properties:anchor:issource:)
Layout-driven jumps: the only direct Apple statement I found is the 2023 talk's "if an object's velocity suddenly changes, that also feels unnatural",
plus the drag and drop rule that a drag image is what moves while the source stays put. No page says literally "do not drive a drag from layout".
https://developer.apple.com/videos/play/wwdc2023/10158/

Haptics: "Impact haptics provide a physical metaphor ... people might feel a tap when a view snaps into place", with Light as "a collision between
small or lightweight UI objects" and Rigid as "a collision between hard or inflexible UI objects". The page asks apps to prefer haptics that
complement other feedback, match intensity and sharpness to the animation, "Avoid overusing haptics", prefer "short haptics that complement discrete
events", and "Make haptics optional". The API is `UIImpactFeedbackGenerator`; the HIG does not prescribe drag haptic points.
https://developer.apple.com/design/human-interface-guidelines/playing-haptics and https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator
Reduce Motion: reduce "automatic and repetitive animations, including zooming, scaling, and peripheral motion", by "Tightening animation springs to reduce bounce effects" and "Tracking
animations directly with people's gestures". App Store Connect adds that removing animation entirely can hurt understanding; prefer a "dissolve,
highlight fade, or color shift".
https://developer.apple.com/design/human-interface-guidelines/accessibility and https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria

## What this suggests for SWIPR

Each line is marked *evidence-backed* or *judgement*.

- Entry structure: wordmark, one large circular primary action, at most one secondary text
button. *Evidence-backed:* one or two prominent buttons per view; limit onscreen controls.
- Wordmark at Large Title size (44/52 pt) or a styled logotype, bottom-weighted with the action
and no footer. *Evidence-backed* for the size and reach zone; *judgement* for the gap.
- Wordmark at or above 4.5:1, secondary label dimmer but above 4.5:1. *Evidence-backed* for the
ratio; *judgement* for opacities.
- Circular diameter 64 to 72 pt, with the label inside if one short line fits and otherwise
below, and an accessibility label in either case. *Evidence-backed* only as a floor (44x44 pt default, 28x28 pt minimum); the size, shape and
placement are *judgement*, since Apple's circular preference is visionOS-only.
- Disabled action with no photos: keep shape and label, neutral fill, dimmed label.
*Judgement.* The HIG requires a press state and no more.
- Grip: a short capsule (about 12 x 24 pt) in a 44x44 pt hit region at the cluster's top edge,
labelled "Move controls", with a stepped alternative in Settings. *Evidence-backed:* the grabber is the documented grabbable indicator and must work
with VoiceOver; 44x44 pt is the default control size; drag and drop asks for alternative ways to act. *Judgement:* the glyph and dimensions, since the
documented grabber is a sheet pill.
- Puck: a translucent circle roughly the cluster's diameter, following the finger one-to-one,
appearing after a few points of movement. *Evidence-backed:* translucent drag image after about three points; one-to-one tracking. *Judgement:*
matching the cluster's shape.
- Three phantom slots at the documented positions, dashed or hairline outlines with a faint
fill, removed when the drag ends, with the nearest highlighted one at a time. *Evidence-backed:* highlight a destination only when it can accept the
item, from one cue at a time, and remove the cue when the item leaves. Highlight by brightness, slight scale and a solid border, not colour alone.
*Evidence-backed:* distinct shapes or icons beyond colour.
- Release in a slot: move the cluster there and hide the phantoms. Release elsewhere: nothing
changes. *Evidence-backed:* invalid drops return the item to its source; a same-container move removes the original only when a move happens.
*Judgement:* reading "release elsewhere changes nothing" as the source never having moved.
- Destination from the projected position, not the raw one. *Evidence-backed:* the Fluid
Interfaces momentum-projection technique. *Judgement:* the deceleration constant.
- Track the finger with an offset and no animation on the tracked value; animate only the snap.
*Evidence-backed:* one-to-one tracking, "look for delays everywhere", drag-image rule.
- Landing bounce at or below about 0.2, and 0 for the frequent slot crossing.
*Evidence-backed:* above about 0.4 "may feel too exaggerated"; bounce 0 is general purpose; avoid motion on frequent interactions; tighten springs
under Reduce Motion. *Judgement:* the duration. The current `response: 0.28, dampingFraction: 0.82` is in the interactive range.
- Carry release velocity into the landing spring. *Evidence-backed:* springs "pick up right
where the gesture ends" and SwiftUI tracks gesture velocity. *Judgement:* the extra plumbing.
- Haptics: one impact on grip pickup, one when the puck enters a new slot, one rigid impact on
landing. *Evidence-backed* that impacts suit a snap and haptics should complement other feedback, not be overused. *Judgement:* the exact mapping,
which the HIG does not prescribe.
- Statistics: top of Settings, inline, non-interactive, semantic labels with numeric values.
*Judgement:* Apple's Settings page describes no read-only information block; the accessible presentation follows the "more than color alone" rule.
*Not settled:* a disclosure row into a dedicated statistics screen. Keep any fuller statistics screen reachable. *Judgement.*

Where the evidence does not settle the choice: no iOS HIG page states a circular button size, label placement or disabled treatment, so every number
above 44 pt is judgement; "grabber" is documented only for resizable sheets; phantom slots are a game convention whose Apple analogue is destination
highlighting and transfer placeholders; no Apple page gives an animation duration or says literally "do not animate against the user's finger"; and
whether a circle or capsule is better on iOS is unresolved because the shape preference is stated only for visionOS.

## Primary sources

- Onboarding, Apple HIG: fast, optional first run, not a prerequisite. https://developer.apple.com/design/human-interface-guidelines/onboarding
- Launching, Apple HIG: uncluttered launch; splash screens are branding, not setup. https://developer.apple.com/design/human-interface-guidelines/launching
- Buttons, Apple HIG: 44x44 pt hit region, one or two prominent buttons per view, style not size, press states, verb-first labels, visionOS circular preference. https://developer.apple.com/design/human-interface-guidelines/buttons
- Typography, Apple HIG: iOS text sizes and the typographic hierarchy idea. https://developer.apple.com/design/human-interface-guidelines/typography
- Dark Mode, Apple HIG: base and elevated backgrounds, 4.5:1 minimum and 7:1 preferred contrast. https://developer.apple.com/design/human-interface-guidelines/dark-mode
- Designing for iOS, Apple HIG: limit onscreen controls; middle or bottom of the display is the reach zone. https://developer.apple.com/design/human-interface-guidelines/designing-for-ios
- Layout, Apple HIG: respect safe areas, differentiate controls from content. https://developer.apple.com/design/human-interface-guidelines/layout
- Accessibility, Apple HIG: iOS 44x44 pt default and 28x28 pt minimum, 12 pt padding, contrast ratios, indicators beyond colour, Reduce Motion reductions. https://developer.apple.com/design/human-interface-guidelines/accessibility
- Sheets, Apple HIG: a grabber indicates a resizable sheet and works with VoiceOver. https://developer.apple.com/design/human-interface-guidelines/sheets
- Drag and drop, Apple HIG: translucent drag image after about three points, highlight only valid destinations while above them, one cue at a time, invalid-drop feedback, placeholders, alternative ways to act. https://developer.apple.com/design/human-interface-guidelines/drag-and-drop
- Motion, Apple HIG: purpose, brevity, cancelability, avoid animating frequent interactions; no millisecond figure. https://developer.apple.com/design/human-interface-guidelines/motion
- Playing haptics, Apple HIG: impacts as the snap metaphor, Light and Rigid meanings, complement other feedback, avoid overuse, make haptics optional. https://developer.apple.com/design/human-interface-guidelines/playing-haptics
- Designing Fluid Interfaces, WWDC 2018 session 803, Apple: response and latency, interruptibility, one-to-one tracking, spatial consistency, hinting, grabber and elevation affordances, momentum projection. https://developer.apple.com/videos/play/wwdc2018/803/
- Animate with springs, WWDC 2023 session 10158, Apple: duration and bounce as universal spring parameters, velocity handoff, bounce 0 general purpose, caution above about 0.4, settling duration is not user-facing timing. https://developer.apple.com/videos/play/wwdc2023/10158/
- Animation.spring(response:dampingFraction:blendDuration:), Apple documentation: parameter meanings, defaults 0.5 / 0.825 / 0. https://developer.apple.com/documentation/swiftui/animation/spring(response:dampingfraction:blendduration:)
- Animation.interactiveSpring(response:dampingFraction:blendDuration:), Apple documentation: interactive variant, defaults 0.15 / 0.86 / 0.25. https://developer.apple.com/documentation/swiftui/animation/interactivespring(response:dampingfraction:blendduration:)
- View.matchedGeometryEffect, Apple documentation: synchronised geometry via a namespace and a source view. https://developer.apple.com/documentation/swiftui/view/matchedgeometryeffect(id:in:properties:anchor:issource:)
- UIImpactFeedbackGenerator, Apple documentation: the impact generator used for snap and collision feedback. https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator
- UIDragPreview, Apple documentation: the preview shown while the finger moves the item, dismissed on drop or cancel. https://developer.apple.com/documentation/uikit/uidragpreview
- Making a view into a drag source, Apple documentation: draggable, custom previews and contentShape for the lift preview. https://developer.apple.com/documentation/swiftui/making-a-view-into-a-drag-source
- Move apps and widgets on the Home Screen, Apple iPhone User Guide: hold until items jiggle, drag, tap the background to finish. https://support.apple.com/guide/iphone/move-apps-and-widgets-on-the-home-screen-iphd2fc8ce30/ios
- Customize your workspace, Apple iPad User Guide: resize by dragging either bottom corner, so a visible corner is the handle. https://support.apple.com/guide/ipad/customize-your-workspace-ipadaf1d4cc9/ipados
- Use AssistiveTouch on iPhone, Apple iPhone User Guide: drag the menu button to move it, Idle Opacity dims it; snapping and persistence undocumented. https://support.apple.com/guide/iphone/use-assistivetouch-iph96b21954/ios
- Reduced Motion evaluation criteria, App Store Connect Help: reduce scaling and multi-axis motion; a dissolve or highlight fade beats removing meaning-bearing animation. https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria
- Touch Controls in the Steam Link App, Steam Support (third party): layout edit mode with an explicit Done, drag-to-place, snapping, copy and reset. https://help.steampowered.com/en/faqs/view/0265-BEF0-5EFF-60DF
