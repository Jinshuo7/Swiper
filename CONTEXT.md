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
The user's verdict on the current photo: keep, favorite, or mark for deletion.
Undo is an action that reverses a decision, not a decision of its own.

**Keep**:
A decision that marks a photo as reviewed and leaves it in the library.

**Favorite**:
A decision that marks the asset as an Apple Photos favorite, keeps it, and
advances.

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
deterministic random order of identifiers.

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

**Control preset**:
The chosen interaction style: Swipe, Thumb, Delete only, or Extended. It changes
which controls are shown, never the full-screen photo experience.

**Control placement**:
Where the floating controls sit: left, center or right, for handedness.

_Avoid_: "progress" for anything other than the current session's confirmed
deletion totals, which are only shown on the statistics screen.
