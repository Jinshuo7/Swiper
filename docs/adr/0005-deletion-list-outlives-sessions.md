# The deletion list outlives sorting sessions

Marking a photo for deletion is a statement about the library, not about the
current pass through it. Recent, Start Here and Tumbler are only different ways
to walk the same photos, so Swiper keeps one ordered deletion list that survives
starting a new session, switching mode and relaunching the app. Marked photos are
skipped while sorting, and home and the viewer both offer a route into review.

A new session resets only what belongs to a session: traversal position, the
decisions made in it, and its Undo history. Undo is bounded by the session
because reversing a decision the user can no longer see or remember is worse than
offering no undo at all. Restoring a mark makes the photo kept for the current
session and removes it from the list, so a later session may present it again.

The alternative — clearing the list whenever a session starts — is simpler to
persist, because marks then live inside the session record. It also throws away
work the user explicitly did, which is the failure this decision exists to
prevent: switching mode would silently discard every mark made so far.

Consequences: marks are stored separately from the session and written with it in
one atomic state so the two can never disagree; Undo entries that would reapply a
restored mark are dropped; and externally removed assets are filtered out of the
list without being counted as deletions Swiper performed.
