# Localisation survey and plan

Status: **surveyed, not migrated.** English is the only shipped language. Nothing
in the app is half-localised: no catalog exists and no call site has been
converted. This document is the preparation for doing it in one pass, because a
partial migration is worse than none — the app would show a mixture of English
and Chinese.

## What exists today

- `Scripts/generate_project.rb` already sets `SWIFT_EMIT_LOC_STRINGS = YES` on
  every target, so Xcode can extract SwiftUI string literals into a String
  Catalog with no per-call-site change.
- `SwiperKit/LibraryCalendar` formats month titles with a locale-aware
  `DateFormatter` (`setLocalizedDateFormatFromTemplate("yMMMM")`). A unit test
  asserts English `"November 2024"` **and** Chinese `"2024年11月"`. Month headers
  therefore need no catalog work at all — the main grid already localises.

## Inventory

About 150 user-facing strings, in these places:

| Area | Approx. | Notes |
| --- | --- | --- |
| `Swiper/Views/` | ~95 | Screens, buttons, wells, tutorial, banners |
| `Swiper/ViewModels/AppModel.swift` | ~16 | Persistence and failure notices |
| `SwiperKit/ControlPreferences.swift` | 21 | Preset and rail titles/subtitles |
| `SwiperKit/DeletionWording.swift` | 9 | The agreed deletion vocabulary |
| `SwiperKit/SessionPersistence.swift` | ~7 | `SessionStoreError.errorDescription` |
| `SwiperKit/Models.swift` | 4 | `SessionAction.title` |
| `SwiperKit/ByteFormatter.swift` | ~5 | "1 byte", "about 1.2 GB" |
| `SwiperKit/LibraryCalendar.swift` | 1 | "No date" |

Non-copy literals that must **not** be localised, and must be excluded from any
blanket extraction: `"mediaType == %d"` (a `PHFetchOptions` predicate), asset
identifiers, `accessibilityIdentifier` values, `UserDefaults` keys, JSON file
names, and the `XCTestConfigurationFilePath` environment key.

## Blockers, in the order they will bite

1. **Framework copy lives in `SwiperKit`, not the app.** A String Catalog in the
   app target does not cover the framework. `DeletionWording`, the rail and
   preset titles, `SessionAction.title`, `ByteFormatter` and
   `SessionStoreError.errorDescription` are all in `SwiperKit`, including the
   strings the user sees most (the marked count, the review button, every error
   banner). These need `SwiperKit/Localizable.xcstrings` plus lookups with
   `bundle: .module`, and the framework target needs a default localisation.
   This is the change that is easy to discover halfway through, which is why it
   is written down first.
2. **Manually pluralised English.** At least six places build plurals by hand:
   `DeletionWording.markedForDeletion`, `"Delete N photos"`, `"Restore N
   selected"`, `"Marked photo N of M"`, `"N photos deleted"`, `"N marked photos
   are no longer in your library…"`. Wrapping these in a lookup without switching
   to catalog plural variants produces wrong output in any language with more
   than one plural form.
3. **Sentence fragments split by interpolation.** `"\(count) \(count == 1 ?
   "photo" : "photos") marked for deletion"` is a fragment plus a conditional
   noun. Chinese word order and measure words differ ("3 张照片已标记删除"), so each
   must become one whole-sentence key with a plural variation, never a
   concatenation.
4. **Wording constraints must survive translation.** `CONTEXT.md` fixes the
   vocabulary: photos are *marked*, never *queued*; "Nothing deleted yet." The
   Chinese must use 标记 (marked), not 队列 (queue). A translator needs that rule
   explicitly, not just the string list.
5. **Accessibility copy is copy.** `"Marked photo N of M"`, `"Press and hold the
   photo to play its motion"`, and every control label are in the inventory and
   need translating too.
6. **Layout under a different language.** Chinese is usually shorter, so
   truncation is unlikely, but `lineLimit(1)` and `minimumScaleFactor` are used on
   the swipe wells and the rail; those need a look in `zh-Hans` rather than an
   assumption.

## Plan — one pass, no intermediate release

1. Add `SwiperKit` localisation: catalog, default localisation, and
   `bundle: .module` lookups for the framework strings listed above.
2. Replace every manual plural with a String Catalog plural variation, so the
   English source changes too (and its tests with it).
3. Add the app catalog, extract, then **curate out** the non-copy literals in the
   table above.
4. Translate `zh-Hans` in a single pass, with the wording constraints from
   `CONTEXT.md` supplied to the translator.
5. Add `zh-Hans` to the project's known regions and ship both.
6. Run `Scripts/check_localizations.sh` — it fails if any key lacks a non-empty
   `zh-Hans` value, which is what makes "no half-migrated strings" enforceable
   rather than a promise.
7. Screenshot every screen in `zh-Hans` and inspect for clipping, especially the
   rail, the wells, the review grid and the tutorial.
8. Record the two-language decision as an ADR.

## What is deliberately not done yet

The migration itself. Doing step 2 or 3 alone would leave the app shipping a
mixture, and step 4 needs a decision that is not mine to make: whether I should
produce a first-pass `zh-Hans` translation for review, or whether translations
will be supplied. The English copy is unchanged and complete.
