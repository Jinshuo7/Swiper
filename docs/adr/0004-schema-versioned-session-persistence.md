# Schema-versioned session persistence

Swiper stores the deletion list and the sorting session as one JSON file on
device. That file outlives app updates, so its shape is a compatibility surface:
a build that cannot read it must not treat it as "the user has no saved work".

The stored state therefore carries an explicit `schemaVersion` and is decoded
against a known migration path. Loading reports one of five outcomes — absent,
loaded, migrated, unreadable, or written by a newer version — instead of
collapsing every decode failure into `nil`. Unreadable and newer-version bytes
block writes until the user explicitly sets the unreadable file aside, which
preserves it under a new name rather than overwriting it.

The alternative — treating any decode failure as an empty session — needs no
version field and no error path, and is what the code did before. It silently
destroys every user's saved work on the first incompatible schema change, which
is exactly the failure this decision exists to prevent.

Consequences: every schema change owes an in-memory migration and a test; the
store can refuse to write, so callers must handle a throwing save and say so in
the UI; migrations are completed by rewriting the file atomically, so the old
bytes survive until the new write succeeds.
