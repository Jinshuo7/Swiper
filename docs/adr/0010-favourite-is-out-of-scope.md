# Favourite is out of scope

SWIPR does not favourite. A decision is keep or mark for deletion, and the
favourite action leaves the engine, the library protocol and the interface. If
someone wants to favourite a photo, the Photos app is where that belongs.

The app exists to clear a library, not to browse and annotate it. Favouriting
serves the second intent: it is the only decision that changes what the library
*means* rather than what happens to the photo next, and its presence cost the
three real actions attention and width at the bottom of the screen, where the
owner wanted three buttons and nothing else.

Alternatives rejected: keeping the heart in a corner or in the control cluster,
which the owner asked to remove outright; and keeping favouriting as a hidden
gesture such as a double tap, which is undiscoverable, cannot be taught in the
same breath as the other decisions, and is the kind of capability that rots once
nothing exercises it.

Consequences: the library protocol loses `setFavorite`, so the app performs no
library effect when a decision is staged and the ordering rules that existed for
favouriting now apply only to deletion; a stored version 2 session may contain a
favourite undo entry, so the state schema moves to 3 with a migration that drops
those entries while leaving the asset recorded as kept; and the tutorial and the
statistics copy no longer mention favourites, which they never counted anyway.
