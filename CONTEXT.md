# CONTEXT

The shared language for Swiper. This file is a glossary only: it defines the
project's words, never its implementation.

## Sessions and traversal

**Session**:
One pass through the library in which the user decides the fate of photos.
A session can be paused, persisted and resumed. Its traversal position, decisions
and Undo history are session-scoped; the [deletion
list](#sessions-and-traversal) is not.

**Decision**:
The user's verdict on the current photo: keep or mark for deletion. Undo is an
action that reverses a decision, not a decision of its own.

**Keep**:
A decision that marks a photo as reviewed and leaves it in the library.

**Mark for deletion**:
A reversible decision that adds a photo to the deletion list. It never removes
anything from the library.

**Deletion list**:
The persistent, ordered set of photos marked for deletion. It belongs to the
library, not to one sorting session: starting a new session, switching mode or
relaunching never clears it, and marked photos are skipped while sorting. Every
mark stays reversible until the final deletion commit. Recorded in
[ADR-0005](docs/adr/0005-deletion-list-outlives-sessions.md).

_User-facing wording_: "Photos marked for deletion", never "queue". Home and the
viewer say "Nothing deleted yet." wherever marks are visible.

**Session-scoped Undo**:
Undo reverses the most recent decision of the current session and returns to that
photo. New sessions reset traversal, in-session decisions and Undo; they never
clear a mark. Restoring a photo drops the Undo entries that could reapply its
mark.

**Traversal direction**:
Whether the session walks toward older or newer photos. Swiper defaults toward
older photos and remembers the user's preference.

**Tumbler**:
A repeat-free randomised traversal of the library. It uses a persisted,
deterministic random order of identifiers. Its entry point is **Random**, inside
Choose a photo.

**Choose a photo**:
The screen for choosing where a sorting session begins. It presents the library
grouped into calendar months, newest first by default, with a menu that jumps
straight to a month, and it starts the two named traversals itself: **Newest**,
which begins at the newest photo and walks toward older ones, and **Random**,
which is the Tumbler. It is the only door into sorting; the entry screen reaches
it and never starts a session on its own.

**Entry screen**:
The first screen: the SWIPR wordmark, one action that opens Choose a photo, a resume
action shown only while a session is waiting, and a chip into deletion review
shown only while photos are marked.

**Deletion review**:
The dedicated screen where marked photos are inspected, restored, or confirmed
for deletion. Reachable from home and from the viewer at any time. Statistics are
never shown here.

**Deletion commit**:
The single, explicit action that asks the system to delete the remaining marked
photos. It is the only destructive operation in the app.

**Restore**:
Removing a photo from the deletion list. A restored photo becomes kept for the
current session, and a later session may present it again.

## Access and safety

**Confirmation**:
A photo only counts as deleted after the system confirms it is gone. Assets that
were only marked, or that a failed or cancelled commit left in place, never
count.

**Limited library**:
The photo access state where only user-selected photos are visible. Swiper
supports it and offers to expand the selection.

**Estimated size**:
The approximate on-disk size of an asset, derived from pixel dimensions and
media kind because PhotoKit exposes no public byte size. Always labelled as an
estimate.

## Media and preferences

**Full-photo presentation**:
The viewer shows the complete asset at its original aspect ratio. Unused screen
area stays black; the viewer never crops an asset merely to fill the display.

**Live Photo**:
A still image with an associated short motion clip. Supported in v1.

**Ordinary video**:
A video asset with no still-photo companion. Deliberately excluded from v1,
including from all statistics.

**Commit threshold**:
The horizontal distance a photo must travel before releasing the drag decides
anything. Crossing it arms the outcome well and gives one light haptic; releasing
below it, or releasing a vertical drag, is not a decision.

**Outcome well**:
A feedback-only area revealed in the lower corner a drag is heading for: trash on
the left, check on the right. It states the prospective outcome with a symbol and
wording, and is never a separate control.

**Tutorial**:
The one-time explanation of marking, keeping, review confirmation and automatic
saving, shown with the first photo and replayable from Settings → How to use. It
is teaching state, not saved work.

**Control cluster**:
The viewer's three controls: Trash, Undo and Checkmark. It is shown only while
buttons are shown, and it never resizes or shifts the photo.

**Control position**:
Where the cluster sits: a row centred near the bottom edge, or a column centred in
the middle of the lower half at the left or right edge. One of exactly three fixed
places, chosen by the user and remembered.

**Grip**:
The three-dot handle on the cluster. Dragging it is how the cluster is moved.

**Puck**:
The small circle the grip becomes while it is dragged, carrying the three dots and
following the finger. The cluster stays where it is until the puck is released.

**Slot**:
A candidate control position, drawn as a phantom outline while the puck is being
dragged. The nearest slot is highlighted; releasing in it moves the cluster there,
and releasing anywhere else changes nothing.

_Avoid_: "progress" for anything other than the current session's confirmed
deletion totals, which are shown in Settings.
