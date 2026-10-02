# The photo never moves for chrome

The viewer fits the asset to the full safe area and never resizes or shifts it
because of a control. The controls float over it.

The screen exists so a person can judge one photo, and the photo is the content.
Anything that moves it while the user is looking at it breaks the one relationship
the screen depends on: the photo stays where it is and the user's thumb goes to
the controls. Apple's fluid-interfaces guidance is unusually direct about this,
requiring one-to-one tracking and spatial consistency during movement, and
warning that "the moment the touch and content stop tracking one-to-one, we
immediately notice it" (`docs/research/entry-and-dock-design.md`).

The alternative, and the decision this reverses, was to reserve a lane: a rail
docked to one edge narrowed the photo's fitted area and shifted it sideways so a
control never sat on top of the photo. That kept the control legible at the cost
of the photo jumping whenever the dock changed, which is what the owner reported
as a bug: "when you change the position of the buttons, it messes with the image
position."

Consequences: a control may overlap the photo, so the controls are drawn as
translucent material with a stroke rather than as opaque shapes, and legibility is
checked against the photo behind them; the viewer's fitting maths takes no input
from the control position; and the overlap assertions in the tests measure
chrome against chrome and against the photo's frame, which the tests now pin as
identical at every control position.
