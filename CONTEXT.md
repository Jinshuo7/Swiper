# CONTEXT

The shared language for SWIPR. This file is a glossary only: it defines the
project's words, never its implementation. It is media-neutral: unless a term
says otherwise, "item" means any photo, Live Photo or ordinary video. The
authoritative production-v1 specification is
[issue #24](https://github.com/Jinshuo7/SWIPR/issues/24).

## Sessions and traversal

**Filter pool**:
The set of library items matching the chosen media types and category filters,
before a starting point or traversal order is chosen. It is editable before a
session; once the session begins, its membership is fixed, so newly added library
items wait for a new session.

**Starting point**:
The item chosen as the beginning of a sorting session within its filter pool.
Random lets the app choose that beginning instead.

**Session**:
One pass through the filter pool in which the user decides the fate of library
items — photos, Live Photos and ordinary videos alike. A session can be paused,
persisted and resumed. Its traversal position, decisions and Undo history are
session-scoped; the [deletion list](#sessions-and-traversal) is not.

**Decision**:
The user's verdict on the current item: keep or mark for deletion. Undo is an
action that reverses a decision, not a decision of its own.

**Keep**:
A decision that marks an item as reviewed and leaves it in the library.

**Mark for deletion**:
A reversible decision that adds an item to the deletion list. It never removes
anything from the library.

**Skip**:
Passing an item without deciding it because no usable preview exists. Skip
records neither Keep nor Mark for deletion, so the item stays eligible later.

**Deletion list**:
The persistent, ordered set of photos and videos marked for deletion. It belongs
to the library, not to one sorting session: starting a new session, switching
mode or relaunching never clears it, and marked items are skipped while sorting.
Every mark stays reversible until the final deletion commit. Recorded in
[ADR-0005](docs/adr/0005-deletion-list-outlives-sessions.md).

_User-facing wording_: "marked for deletion", never "queue". Home and the viewer
say "Nothing deleted yet." wherever marks are visible.

**Session-scoped Undo**:
Undo reverses the most recent decision of the current session and returns to that
item. New sessions reset traversal, in-session decisions and Undo; they never
clear a mark. Restoring an item drops the Undo entries that could reapply its
mark.

**Traversal direction**:
Whether the session walks toward older or newer items. SWIPR defaults toward
older items and remembers the user's preference. Traversal completes at the end
of the selected walk rather than wrapping.

**Tumbler**:
A repeat-free randomised traversal of the filter pool. It uses a persisted,
deterministic random order of identifiers. Its entry is **Random** on the
starting-point grid.

**Home**:
The first screen. It offers the media choices **Everything**, **Photos** and
**Videos** (each of which opens editable filters), a conditional **Continue
sorting** action, a separate conditional **Review marked items** action, Settings
and Review in mirrored top corners, and a quiet conditional **Your impact**
section. It does not start a session on its own.

**Starting-point grid**:
The screen for choosing where a sorting session begins. It presents the filter
pool grouped into calendar months, newest first by default, with a month jump and
order choice. It offers the named traversals **Newest first**, **Oldest first**
and **Random** (the Tumbler), plus choosing a specific item.

**Deletion review**:
The dedicated screen where marked photos and videos are inspected, restored, or
confirmed for deletion. Reachable from Home and from the viewer at any time.
Statistics are never shown here.

**Deletion commit**:
The single, explicit action that asks the system to delete the remaining marked
items. It is the only destructive operation in the app.

**Restore**:
Removing an item from the deletion list. A restored item becomes kept for the
current session, and a later session may present it again.

## Access and safety

**Confirmation**:
An item only counts as deleted after the system confirms it is gone. Items that
were only marked, or that a failed or cancelled commit left in place, never
count.

**Limited library**:
The photo access state where only user-selected items are visible. SWIPR supports
it and offers to expand the selection.

**Estimated size**:
The approximate on-disk size of an item, derived from public metadata — pixel
dimensions, and duration for video — because PhotoKit exposes no public byte size.
Always labelled as an estimate.

## Media and preferences

**Media kind**:
One of **Photo**, **Live Photo** or **Ordinary video**. All three are supported
in v1.

**Live Photo**:
A still image with an associated short motion clip. Supported in v1.

**Ordinary video**:
A video item with no still-photo companion. Supported in v1: it is sorted,
played and reviewed alongside photos.

**Full-item presentation**:
The viewer shows the complete item at its original aspect ratio. Unused screen
area stays letterboxed; the viewer never crops an item merely to fill the display.

**Commit threshold**:
The horizontal distance an item must travel before releasing the drag decides
anything. Crossing it arms the outcome well and gives one light haptic; releasing
below it, or releasing a vertical drag, is not a decision.

**Outcome well**:
A feedback-only area revealed in the lower corner a drag is heading for: delete on
the left, keep on the right. It states the prospective outcome with a symbol and
wording, and is never a separate control.

**Tutorial**:
The one-time explanation of marking, keeping, review confirmation and automatic
saving, shown with the first item and replayable from Settings → How to use. It is
teaching state, not saved work.

**Decision dock**:
The viewer's neutral decision controls: a centred **Delete** and **Keep** pair
with a separate **Undo** control. The whole dock is draggable from its buttons or
gaps — there is no permanent grip — and it morphs into a compact **token** while
moving. It sits at one of exactly three fixed positions and never resizes or
shifts the item.

_Avoid_: "cluster", "grip", "puck" and "slot" for the current dock.

**Control position**:
Where the dock sits: **Left**, **Bottom** or **Right**. One of exactly three
fixed places, chosen by the user, remembered immediately, and also selectable in
Settings.

**Token**:
The compact neutral form the dock becomes while it is being moved. Releasing at a
valid destination restores the full controls; an invalid release returns them to
the source.

**Undo position**:
Whether Undo sits **Before actions** (the default) or **After actions**, read
relative to the Delete/Keep pair in the current layout.

_Avoid_: "progress" for anything other than the current session's confirmed
deletion totals, which are shown in Settings.
