# Remove favouriting from the product

## Parent

#17

## What to build

Favourite leaves SWIPR. The app is for clearing photos, and favouriting costs the
three real actions attention and space. A decision becomes keep or mark for
deletion.

Remove it end to end rather than hiding the button, so no dead capability is left
behind:

- `SessionAction.favorite`, `SessionEffect.setFavorite`, and the favourite undo
  entry.
- `PhotoLibraryProviding.setFavorite`, the real implementation, and the fake's
  favourite faults and write log.
- The heart from the viewer, the tutorial copy that teaches it, and the entry
  screen copy that mentions it.
- The tests that exist only for favouriting.

Then keep the persistence honest: stored sessions can contain favourite undo
entries, so bump `PersistedState.currentSchemaVersion` to 3 and migrate a v2
payload by dropping those entries while keeping the asset recorded as kept.

## Acceptance criteria

- [ ] No user-facing surface mentions favouriting, and no unreachable favourite
      code remains in the engine, the library protocol, the fakes or `AppModel`.
- [ ] A v2 payload containing a favourite undo entry loads without loss: the
      entry is dropped, the asset stays kept, and a test proves it.
- [ ] `AppModel` keeps save, failure and retry behaviour for state; the tests that
      proved effect ordering across a failed save are rewritten around deletion
      rather than deleted.
- [ ] Statistics are unchanged: favourites were never counted, and the numbers a
      v2 run would have produced are still what a v3 run produces.
- [ ] `SWIPRKitTests` and `SWIPRAppTests` are green, and the full suite is green on
      the device.
- [ ] `CONTEXT.md` and `docs/SPEC.md` describe decisions as keep or mark for
      deletion.

## Blocked by

`08-redesign.md`.
