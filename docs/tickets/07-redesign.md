# Record the redesign decisions

## Parent

#17

## What to build

Write the decisions that the redesign depends on into the repository's own
records, before any behaviour changes, so the rename and the code that follows
are written against settled vocabulary.

- Five ADRs in `docs/adr/`, following the existing format: the photo never moves
  for chrome; three fixed control positions moved with a puck; Start Here owns
  every entry into sorting; swipe is always available and buttons are optional;
  favourite is out of scope.
- Correct `CONTEXT.md`. It currently defines *Control preset* as "Swipe, Thumb,
  Delete only, Extended" and *Control placement* as "left, center or right",
  neither of which matches the shipped app. *Decision* loses favourite, *Favorite*
  is deleted, *Recent* retires, and the new terms (grip, puck, slot, position)
  are defined. It stays a glossary: no implementation detail.
- Point `AGENTS.md` and `docs/TESTING.md` at the new spec and research note where
  a future session would look for them.

## Acceptance criteria

- [ ] Every ADR states the decision, the alternatives rejected, and the
      consequence a future reader would otherwise find surprising.
- [ ] No ADR repeats an implementation detail that the spec already carries.
- [ ] `CONTEXT.md` contains no term that the shipped app no longer uses, and no
      term that the spec introduces is missing from it.
- [ ] `CONTEXT.md` remains a glossary only.
- [ ] Every claim in the ADRs that depends on Apple guidance cites the research
      note rather than restating it.

## Blocked by

None (can start immediately).
