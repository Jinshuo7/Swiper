# CONTEXT

The shared language for Swiper. This file is a glossary only: it defines the
project's words, never its implementation.

## Sessions and traversal

**Session**:
One pass through the library in which the user decides the fate of photos.
A session can be paused, persisted and resumed.

**Decision**:
The user's verdict on the current photo: keep, favorite, or queue for deletion.
Undo is an action that reverses a decision, not a decision of its own.

**Keep**:
A decision that marks a photo as reviewed and leaves it in the library.

**Favorite**:
A decision that marks the asset as an Apple Photos favorite, keeps it, and
advances.

**Queue for deletion**:
A reversible decision that adds a photo to the deletion queue. It never removes
anything from the library.

**Deletion queue**:
The ordered set of photos queued for deletion in the current session. Every
member is reversible until the final deletion commit.

**Traversal direction**:
Whether the session walks toward older or newer photos. Swiper defaults toward
older photos and remembers the user's preference.

**Tumbler**:
A repeat-free randomised traversal of the library. It uses a persisted,
deterministic random order of identifiers.

**Deletion review**:
The dedicated screen where queued photos are inspected, restored, or confirmed
for deletion. Statistics are never shown here.

**Deletion commit**:
The single, explicit action that asks the system to delete the remaining queued
photos. It is the only destructive operation in the app.

**Restore**:
Removing a photo from the deletion queue. A restored photo becomes kept.

## Access and safety

**Confirmation**:
A photo only counts as deleted after the system confirms it is gone. Assets that
were only queued, or that a failed or cancelled commit left in place, never
count.

**Limited library**:
The photo access state where only user-selected photos are visible. Swiper
supports it and offers to expand the selection.

**Estimated size**:
The approximate on-disk size of an asset, derived from pixel dimensions and
media kind because PhotoKit exposes no public byte size. Always labelled as an
estimate.

## Media and preferences

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
