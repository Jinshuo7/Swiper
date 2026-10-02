# Swipe is always available and the buttons are optional

Dragging the photo always decides. The three controls are a display option, on by
default, and turning them off hides the cluster and its grip; nothing about
swiping changes either way.

The two ways of deciding serve different moments: a drag is the fast one-handed
path, and the buttons are the deliberate one and the alternative for anyone who
cannot or does not want to gesture, which is the accessibility argument for having
them at all. A choice between the two was never the point, so the app offers both
and lets the user remove the one they do not want on screen.

That replaces the preset list, which had shrunk to a single boolean. Once the
controls stopped varying by preset, "Extended" behaved identically to "Swipe" and
"Delete only" existed to remove a button that is now always present; a list whose
members differ by one bit is a list pretending to be a setting.

Alternatives rejected: presets that decide which controls exist, because the same
screen then behaves differently per preset and the user has to remember which one
they are in; and gestures as the only path, because it removes the non-gesture
way to act that the accessibility guidance asks for.

Consequences: the settings row is a toggle rather than a list, and it names what
it shows rather than what it enables; hiding the cluster must keep every decision
reachable, which the swipe and the top strip's review entry do; the tutorial
teaches the drag first and mentions the buttons as the alternative; and the
cluster's position settings stay meaningful only while the cluster is shown.
