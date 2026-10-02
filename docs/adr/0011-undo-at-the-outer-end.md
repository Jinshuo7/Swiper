# Undo sits at the outer end of the cluster

**Status: AMENDED** by production-v1 (issue #24, 2026-10-01). Delete and Keep stay
adjacent with Undo at an outer end, and the two-value setting is retained — but it
is now read as **Before actions** (default) / **After actions** rather than
left/right, and the dock is moved by direct whole-dock dragging with no grip. See
[`docs/SPEC.md`](../SPEC.md) §5.6. The reasoning below about keeping the pair
adjacent and avoiding misclicks remains normative.

## Original decision

Undo leaves the middle of the control cluster and sits at one outer end; Trash
and Keep stay adjacent as the pair. The end is a user setting with two values,
which the user reads as left and right (leading and trailing in the code, so a
side column reads top and bottom).

A decision is reversible only by Undo, and it is the least frequent action. In
the middle it took a slot between the two actions someone actually reaches for,
so a thumb aiming at Keep or Trash could land on Undo — an accidental reversal of
the last decision instead of the decision itself. Keeping Trash and Keep adjacent
also repeats the swipe wells' own mapping, delete on the left and keep on the
right, so the button row and the gesture teach the same spatial rule. The owner
raised the misclick directly ("it might incur more misclicks than providing
actual maximized value").

Alternatives rejected: the literal corner button the owner first described, which
would either collide with the bottom row (which already spans most of a 375 pt
screen) or force the pair smaller, double the movable state, and overlap the
lower end of a side-docked column; and removing Undo altogether, which throws
away the one safety net the app has between a decision and a deletion.

Consequences: the stored preferences gain a two-way `undoSide` (default
`leading`), the cluster's internal order is a pure function of it, and the grip
moves to the end opposite Undo so the handle and the recovery action do not
compete for the same corner. The geometry — tray size, the three positions and
the slot hit-testing — is unchanged, so the move gesture is untouched.
