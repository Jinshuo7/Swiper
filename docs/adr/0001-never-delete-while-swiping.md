# Never delete while swiping

Swiper deliberately separates deciding from deleting. Swiping left only adds a
photo to a reversible deletion queue; the library is mutated exactly once, at an
explicit final confirmation in the deletion review, and only for the photos that
remain queued.

The alternative — deleting inline as the user swipes — is faster to build and
feels more immediate, but it makes every accidental swipe permanent and forces
either a system dialog per photo or a dangerous undo window. Queue-then-commit
costs one extra review screen and buys a safety property the product depends on:
every destructive action is visible, inspectable and reversible until the user
confirms it. This is the app's central contract and is expensive to change
later, so it is recorded here.

Consequences: sessions must persist a deletion queue; the review screen must
support restore and batch restore; statistics must only ever move on confirmed
deletions.
