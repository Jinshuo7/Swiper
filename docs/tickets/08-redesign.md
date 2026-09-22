# Rename the project to SWIPR

## Parent

#17

## What to build

Rename everything a developer or the phone sees, keeping the git and GitHub
repository names as they are because tooling references the checkout path.

`Scripts/generate_project.rb` is the source of truth: change it and regenerate,
rather than editing the project file by hand.

- Framework module `SwiperKit` to `SWIPRKit`, and every `import` in the app and
  every test target follows.
- Source directories, targets, scheme and product names: `SWIPR`, `SWIPRKit`,
  `SWIPRKitTests`, `SWIPRAppTests`, `SWIPRUITests`.
- Bundle identifiers, including the app's, to `com.zhangjinshuo.swipr`, and the
  test bundles to match the new target names.
- Docs prose says SWIPR.
- Record in the commit message that the phone starts empty: marks, session,
  statistics and preferences live in the container keyed by bundle id, and the
  old install stays until it is deleted by hand.

## Acceptance criteria

- [ ] `grep -ri` for the old module, target, scheme and bundle names across
      sources, scripts and docs returns nothing that must change; the only
      remaining uses are the repository path and historical records such as
      ADR text and `docs/IMPLEMENTATION-STATUS.md`.
- [ ] `Scripts/run-kit-tests.sh` is green without the old names appearing in its
      output.
- [ ] `xcodebuild build-for-testing` succeeds for the generic iOS destination, so
      all four targets compile under the new names.
- [ ] The full suite runs green on the device, with the new scheme and bundle ids,
      and the previously installed app is noted as still present on the phone.
- [ ] No behavioural change: the only diff is names, identifiers and the project
      regeneration.

## Blocked by

`07-redesign.md`.
