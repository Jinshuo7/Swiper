# Three fixed control positions, moved with a puck

The three controls live at exactly three positions: a row centred on the screen
width near the bottom edge, and columns centred in the middle of the lower half at
the left and right edges. They move by dragging a three-dot grip. The grip lifts
into a small translucent puck that the finger carries while the cluster itself
stays put, the three positions appear as phantom slots with the nearest
highlighted one at a time, releasing in a slot moves the cluster there, and
releasing anywhere else changes nothing.

Free placement along an edge, which this replaces, made the controls' whereabouts
a per-user fact with nothing on screen to say where they could go, and it produced
the accidental moves the long-press-to-lift was there to prevent. Fixed stops make
the destinations knowable before the drag starts, and the puck makes the drag's
subject unambiguous: what follows the finger is a handle, not the buttons. Apple's
drag-and-drop guidance supplies the rules the slots follow, a translucent drag
image after a few points, highlighting only a destination that can accept the
item, one cue at a time, and an invalid drop returning the item to its source;
the slot grid itself is a game convention with no Apple equivalent, which the note
records rather than dresses up.

Alternatives rejected: keeping the continuous position and adding a drag handle
(the position stays unlearnable); lifting the whole cluster with a long press,
which delayed the drag and is the jank the owner reported; and offering only a
Settings choice with no drag, which cannot put the controls under the thumb that
is actually holding the phone.

Consequences: the stored position is a three-way choice again, so the continuous
position and its anchor migration are deleted rather than extended; a drag of the
grip is a display change that can never decide a photo; the position is reachable
without a drag through Settings and an accessibility action; and the landing is
the only animated part of a move, because the tracked puck must stay exactly under
the finger.
