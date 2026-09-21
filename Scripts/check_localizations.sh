#!/usr/bin/env bash
#
# Guards the "no half-migrated strings" rule for Swiper's localisation.
#
# Every String Catalog in the tree must give a non-empty translation for each
# language the app claims to ship. A catalog that is missing a key, or has an
# empty one, fails: an app that shows English in some places and Chinese in
# others is worse than one that is only English.
#
# While no catalog exists yet, the script reports that and exits 0 — the plan
# lives in docs/LOCALIZATION.md. Once a catalog lands, this is the check that
# stops a partial migration from being committed.
#
# Usage: Scripts/check_localizations.sh [language]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LANGUAGE="${1:-zh-Hans}"

# `mapfile` is not in the bash 3.2 that macOS ships, so build the list by hand.
CATALOGS=()
while IFS= read -r catalog; do
  CATALOGS+=("$catalog")
done < <(find "$ROOT" -name '*.xcstrings' -not -path '*/.build*' -not -path '*/.derivedData*' -not -path '*/.tmp/*' | sort)

if [[ ${#CATALOGS[@]} -eq 0 ]]; then
  echo "No .xcstrings catalogs yet; nothing to check."
  echo "See docs/LOCALIZATION.md for the migration plan."
  exit 0
fi

echo "==> Checking ${#CATALOGS[@]} catalog(s) for '$LANGUAGE'"
python3 - "$LANGUAGE" "${CATALOGS[@]}" <<'PY'
import json
import sys

language = sys.argv[1]
failures = []
checked = 0

for path in sys.argv[2:]:
    with open(path, encoding="utf-8") as handle:
        catalog = json.load(handle)
    for key, entry in catalog.get("strings", {}).items():
        checked += 1
        value = entry.get("localizations", {}).get(language, {})
        rendered = value.get("stringUnit", {}).get("value", "")
        if not rendered.strip():
            # Plural variations live under `variations.plural` instead.
            variations = value.get("variations", {}).get("plural", {})
            rendered = "".join(
                case.get("stringUnit", {}).get("value", "") for case in variations.values()
            )
        if not rendered.strip():
            failures.append(f"{path}: {key}")

if failures:
    print(f"FAIL: {len(failures)} of {checked} keys have no '{language}' translation:")
    for line in failures[:50]:
        print(f"  {line}")
    if len(failures) > 50:
        print(f"  … and {len(failures) - 50} more")
    sys.exit(1)

print(f"OK: {checked} keys all have a '{language}' translation.")
PY
