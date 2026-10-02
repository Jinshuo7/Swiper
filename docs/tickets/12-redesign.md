# Play the finished app as a human and report the experience

## Parent

#17

## What to build

The owner's standing instruction for the end of this work: use SWIPR on the phone
the way a person would, then rate it and report.

Play it end to end against the fake library, which is how a person's session is
reproduced without touching real photos. Every feature and every scenario the app
claims, including the ones that are easy to skip: both kinds of decision, the
undo stack, review and restore, a cancelled deletion, a confirmed deletion, the
two failure banners, an interrupted session, a relaunch, the empty library, the
largest text size, and every control position.

Then record, in `docs/ux-review.md`:

- what was played, with the screen's own screenshots attached to the run;
- a rating for each screen and for the flow as a whole, on a stated scale, each
  with the reason rather than a bare number;
- the improvements worth making, ranked, each saying what it would cost;
- the things that were uncertain, with the decision the owner has to make and the
  options, kept separate from the things that were simply fixed.

Fix the common-sense defects found while playing, in the same commit as the test
that would have caught them, and leave anything that is a matter of taste or a
product decision in the report instead of changing it.

## Acceptance criteria

- [ ] Every feature in `docs/SPEC.md` has been exercised on the device, or the
      report says which ones cannot be and why.
- [ ] Every screenshot from the session has been inspected by eye, not just
      generated, and the report says what each one established.
- [ ] The rating covers each screen, and every rating has a reason.
- [ ] Every fix made during the session has a test, or the report says why it
      cannot have one.
- [ ] Uncertainties are listed with the owner's decision spelled out, and are not
      mixed in with the fixes.
- [ ] The report is written so the owner can read it once and act on it.
- [ ] No real photo library is touched: every run launches with
      `-uiTestingFakeLibrary`.

## Blocked by

`11-redesign.md`.
