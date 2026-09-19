# Slice 1a / 1b ticket queue

One ticket file = one commit. Work in the listed merge order; re-run
`Scripts/run-kit-tests.sh` after every merge and do not merge the next one while it is red.

## Merge order
  Wave 0   T-0.1 -> T-0.2 -> T-0.3        (one session, serial)
  Wave 1   T-1.1 -> T-1.3   |  T-1.2 -> T-1.4   |  T-2.1 -> T-2.2    (three worktrees, parallel)
  Wave 2   T-3.1                          (one session, serial, DELETION ONLY)
  Wave 3   T-4.1                          (one session, serial, adds files -> owns project regen)
  Wave 4   T-5.1 -> T-5.2 -> T-5.3        (one session, serial)

## Rules
- Never edit Swiper.xcodeproj by hand. After adding, renaming or deleting a source file,
  run `ruby Scripts/generate_project.rb` and commit the result in the same commit.
- `SwiperKit` stays Foundation-only. The engine never mutates a library.
- Statistics move only on a confirmed DeletionOutcome.
- Automated tests never touch a real photo library.
- Commit message: `<ticket>: <what changed> (SPEC <clause>)`.
- Read ONLY your ticket and AGENTS.md. The ticket carries the spec text you need.
