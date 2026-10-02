# Movable controls research

> **Historical research note.** The product questions this investigation left
> open are now settled by [issue #24](https://github.com/Jinshuo7/Swiper/issues/24)
> and [`docs/SPEC.md`](../SPEC.md); those sources are authoritative.

## Question

The owner wants the viewer's three remaining controls (Trash, Undo, Checkmark)
to be movable, modelled on the iOS app that streams a Windows PC to an iPhone.
This note establishes what that app moves and how, what Apple's own repositionable
control does, how comparable iOS apps compare, and what model Swiper should copy.

## Findings

### Windows App for iOS (the app the owner meant)

The app is Microsoft's **Windows App Mobile**, previously "Remote Desktop Mobile"
and "RD Client" (https://apps.apple.com/us/app/windows-app-mobile/id714464092).

What moves is the **in-session connection bar**, a single bar, not individual
buttons. Microsoft's iOS/iPadOS release notes describe it:

- "You can now collapse the connection bar by moving it into one of the four
  corners of the screen. On iPads and large iPhones you can dock the connection
  bar to the left or right edge of the screen." (10.2.4)
- "You can minimize the connection bar by dragging it to a corner of the screen.
  To return the connection bar to its regular size, drag it to the center of the
  screen." (10.4.8)
- "The iOS client will also save the position you dock your screen in across all
  your iPad and iPhone devices." (10.4.7)
- The bar "fade[s] back after three seconds" if minimized, with a
  Shift-Command-Space shortcut to toggle visibility (10.4.0), and it collapses on
  a press-and-hold of the Remote Desktop logo (10.0.0).

Source: https://learn.microsoft.com/en-us/previous-versions/remote-desktop-client/whats-new-ios-ipados

So: the whole bar moves, dragged by the bar itself with no handle and no edit
mode described. It snaps rather than floats, docking to an edge or collapsing
into a corner; dragging to the centre restores full size. The bar fades three
seconds after being minimized and translucency is never mentioned. The position
persists across the client's iPad and iPhone devices. Edge docking is described
only for "iPads and large iPhones", so on a smaller iPhone the documented
behaviour is corner collapse. No point sizes or spacing are published.

Two negative findings matter. **Microsoft's current documentation does not
describe the behaviour at all:** the Windows App table of contents has no
connection-bar article (https://learn.microsoft.com/en-us/windows-app/toc.json)
and the only connection-bar entry on the current release notes is for the Windows
platform (https://learn.microsoft.com/en-us/windows-app/whats-new), so it
survives only in the older notes above. And the iPhone screenshots on the App
Store page show the connection centre device list, not a live session, so they
establish nothing about the bar.

On safe areas the client hid the Home indicator and painted under it: "The remote
session can now extend underneath the Home indicator on iPhones" (10.0.5). That
is an immersive convention, not obviously right for a photo viewer.

### Apple's own precedent: AssistiveTouch

The iPhone User Guide says "To move the AssistiveTouch menu button, drag it to a
new location on the screen", and lists **Idle Opacity** among its settings
(https://support.apple.com/guide/iphone/use-assistivetouch-iph96b21954/ios). That
verifies dragging anywhere and dimming when idle. It does **not** state edge
snapping, persistence across restarts, or any reset affordance, so those stay
unverified. The HIG asks apps to support AssistiveTouch and related mobility
technologies
(https://developer.apple.com/design/human-interface-guidelines/accessibility).

### Apple's guidance on controls drawn over content

**Game controls.** Frequently used controls should be "a minimum size of 44x44 pt,
and less important controls, such as menus, are a minimum size of 28x28 pt".
Buttons should not "overlap system features like the Home indicator or Dynamic
Island on iPhone", frequently used buttons go "near a player's thumb", controls
should "show and hide ... to reflect gameplay", and placement should be dynamic:
"opt to show a virtual thumbstick wherever the player lands their thumb instead
of a static thumbstick position."
https://developer.apple.com/design/human-interface-guidelines/game-controls

Correction to the brief: **this page contains no instruction to let people
reposition controls.** I read it in full and found no such rule. The movable
pattern is a shipping-app convention (Windows App, Steam Link, AssistiveTouch),
not a documented Apple rule.

**Hit targets and spacing.** "Strive to meet the recommended minimum control size
for each platform": for iOS the default is 44x44 pt and the minimum 28x28 pt.
"Consider spacing between controls as important as size ... about 12 points of
padding around elements that include a bezel." The Buttons page agrees that "a
button needs a hit region of at least 44x44 pt"
(https://developer.apple.com/design/human-interface-guidelines/buttons).

**Safe areas and content.** "Respecting the safe area is essential to make sure
system UI and hardware features like the Dynamic Island don't obstruct content
and controls"; a safe area is "the area within a window that isn't covered on the
edge by a hardware feature". "Differentiate controls from content."
https://developer.apple.com/design/human-interface-guidelines/layout

**Gestures.** "Avoid conflicting with gestures that access system UI ... people
expect these controls to work consistently."
https://developer.apple.com/design/human-interface-guidelines/gestures

### Comparable iOS apps with on-screen controls

Supporting evidence only, and the pattern is uneven. Only Steam Link documents
the mechanics: touch controls are edited from a `[...]` button, where "Select
**Edit Layout** to move/scale/remove existing controls", "To place a control,
simply touch it and begin dragging it", and "You can also copy or reset layouts".
Controls "snap into default positions", edits commit only on **Done**, and "The
controls vanish after a few seconds of being idle"
(https://help.steampowered.com/en/faqs/view/0265-BEF0-5EFF-60DF).

The rest show no move feature in vendor text or source. Moonlight describes
touchscreen or gamepad play with no rearranging, and its client source lays out
fixed arrangements per controller type
(https://github.com/moonlight-stream/moonlight-ios/blob/master/Limelight/Input/OnScreenControls.m).
Xbox Cloud Gaming layouts are developer-authored into fixed zones and slots
(https://learn.microsoft.com/en-us/gaming/gdk/docs/features/common/game-streaming/building-touch-layouts/game-streaming-tak-designers-guide).
PS Remote Play (https://apps.apple.com/us/app/ps-remote-play/id1436192460),
Shadow PC (https://apps.apple.com/us/app/shadow-pc/id1446621967) and Jump Desktop
(https://apps.apple.com/us/app/jump-desktop-rdp-vnc-fluid/id364876095) say
nothing about moving controls; Jump Desktop's support site returned HTTP 403 to
automated fetching, so its toolbar is unverified.

## What this suggests for Swiper

1. **Move the cluster as one unit, dragged by its own background.**
   *Evidence-backed:* Windows App moves the whole bar and AssistiveTouch moves
   its button; no app documents a drag handle. Steam Link drags individual
   controls, but only in an edit mode. *Judgement:* with three controls, one
   container is simpler and keeps the photo clearer.

2. **Snap to the left or right edge, vertical position free.**
   *Evidence-backed:* Windows App docks to a left or right edge and collapses into
   corners rather than floating centrally (10.2.4, 10.4.8). *Judgement:* snap x to
   the nearer edge on release and clamp inside the safe area, so the cluster never
   sits over the photo's centre. *Not settled:* whether snapping beats free
   placement in the lower third; Windows App chose snap, at the cost of the
   owner's literal "movable".

3. **Remember the position, and offer a reset.** *Evidence-backed:* the Remote
   Desktop client saves the docked position across its devices (10.4.7); Steam
   Link offers "copy or reset layouts". *Judgement:* store the position alongside
   the existing handedness preference, with a "Reset control position" row in
   Settings.

4. **Dim when idle, do not fully hide.** *Evidence-backed:* Steam Link hides
   controls after a few idle seconds and restores them on touch; the Windows App
   bar fades three seconds after being minimized; AssistiveTouch has Idle
   Opacity. *Judgement:* dim, not hide, because the buttons are also the
   non-gesture way to keep or delete and the HIG asks for more than one way to
   act, so hiding would leave swiping as the only path until the next touch.

5. **Sizes: 44x44 pt hit regions, a smaller X glyph.** *Evidence-backed:* the HIG
   asks 44x44 pt for frequently used controls and says a button "needs a hit
   region of at least 44x44 pt"; the iOS minimum is 28x28 pt. *Judgement:* draw the
   X smaller as asked but keep its tappable region at 44x44 pt, with about 12 pt
   padding between controls, so only the artwork shrinks.

6. **Stay inside the safe area and off the Home indicator.** *Evidence-backed:*
   the HIG asks apps to respect safe areas and not to overlap the Home indicator
   or Dynamic Island on iPhone; the Windows App team hid the Home indicator and
   painted beneath it (10.0.5). *Judgement:* do not copy that. Inset the cluster
   by the safe area plus a small margin; a missed tap in the Home indicator strip
   exits to the Home Screen. *Not settled:* the exact margin; neither publishes
   one.

7. **Gate moving behind a deliberate, modal gesture.** This matters most, because
   the cluster sits on a full-screen photo whose left and right swipe decides keep
   or delete. *Evidence-backed:* the HIG says to avoid gestures that conflict with
   expected interactions, and Steam Link puts movement in a separate edit mode
   entered from the `[...]` button, where drags move controls and which must be
   left with **Done** before the controls work again. *Judgement:* do not let a
   plain drag move the cluster during normal viewing. Enter a move mode from
   Settings ("Edit control position") or a touch-and-hold on the cluster, signal
   the mode clearly (Steam Link tints the screen), and exit on a tap outside. An
   edit mode costs one deliberate action, but a bare drag would compete with the
   swipe the app is built around. A cheaper alternative, less supported by
   evidence, is to make only the cluster's empty background draggable; with three
   tightly packed buttons that area is small, so I prefer the explicit mode.

8. **Questions this research left open (now superseded).** Horizontal row versus vertical stack; whether the cluster
   may sit in the top half; whether the snap animates; whether move mode also lets
   people reorder the three actions. No source covers a three-button cluster.

## Primary sources

- Windows App Mobile, App Store: identifies the app; its screenshots show no live session. https://apps.apple.com/us/app/windows-app-mobile/id714464092
- What's new in the Remote Desktop client for iOS and iPadOS, Microsoft Learn: the connection bar moves as a whole, docks to edges on large devices, collapses into corners, fades after three seconds, is saved across devices, and the Home indicator was hidden and painted under. https://learn.microsoft.com/en-us/previous-versions/remote-desktop-client/whats-new-ios-ipados
- Windows App table of contents, Microsoft Learn: no current article on the connection bar. https://learn.microsoft.com/en-us/windows-app/toc.json
- What's new in Windows App, Microsoft Learn: the only current connection-bar entry is for Windows. https://learn.microsoft.com/en-us/windows-app/whats-new
- Human Interface Guidelines, Game controls, Apple: 44x44 pt and 28x28 pt minimum sizes, staying off the Home indicator and Dynamic Island, thumb reach, show/hide by context, dynamic thumbstick placement, and no rule about repositionable controls. https://developer.apple.com/design/human-interface-guidelines/game-controls
- Human Interface Guidelines, Accessibility, Apple: iOS default 44x44 pt and minimum 28x28 pt, control spacing, about 12 pt padding for bezelled elements, and support for AssistiveTouch. https://developer.apple.com/design/human-interface-guidelines/accessibility
- Human Interface Guidelines, Buttons, Apple: a button needs a hit region of at least 44x44 pt. https://developer.apple.com/design/human-interface-guidelines/buttons
- Human Interface Guidelines, Layout, Apple: respect safe areas, the definition of a safe area, and differentiating controls from content. https://developer.apple.com/design/human-interface-guidelines/layout
- Human Interface Guidelines, Gestures, Apple: avoid conflicts with system gestures, give more than one way to act, touch and drag moves an object. https://developer.apple.com/design/human-interface-guidelines/gestures
- iPhone User Guide, Use AssistiveTouch on iPhone, Apple: the menu button is moved by dragging it; Idle Opacity dims it when idle; silent on snapping, persistence and reset. https://support.apple.com/guide/iphone/use-assistivetouch-iph96b21954/ios
- Steam Support, Touch Controls in the Steam Link App, Valve: layout edit mode, dragging controls into place, snapping to default positions, copy and reset, and controls vanishing after a few idle seconds. https://help.steampowered.com/en/faqs/view/0265-BEF0-5EFF-60DF
- Game Development Kit, A designer's guide to building touch controls, Microsoft: Xbox Cloud Gaming layouts are developer-authored into fixed zones and slots, with no player repositioning described. https://learn.microsoft.com/en-us/gaming/gdk/docs/features/common/game-streaming/building-touch-layouts/game-streaming-tak-designers-guide
- Moonlight Game Streaming, App Store, and its iOS client source: vendor text does not mention movable controls, and the client defines fixed default layouts per controller type. https://apps.apple.com/us/app/moonlight-game-streaming/id1000551566 and https://github.com/moonlight-stream/moonlight-ios/blob/master/Limelight/Input/OnScreenControls.m
- PS Remote Play, App Store: describes an on-screen controller with no repositioning. https://apps.apple.com/us/app/ps-remote-play/id1436192460
- Shadow PC, App Store: no mention of movable controls. https://apps.apple.com/us/app/shadow-pc/id1446621967
- Jump Desktop, App Store: no mention of movable controls; its vendor support site returned HTTP 403 to automated fetching, so its toolbar is unverified. https://apps.apple.com/us/app/jump-desktop-rdp-vnc-fluid/id364876095
