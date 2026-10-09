#!/usr/bin/env python3
"""Seed the installed app's SWIPR store for the Round 4 Home screenshots.

The app is installed on the `SWIPR iPhone 11 Pro` simulator. This script:

1. reads the real asset identifiers out of that simulator's Photos database, so
   the app's own reconciliation keeps the marks and the resumable session;
2. writes `statistics.json` with a lifetime impact (`About 2.4 GB freed ·
   860 items deleted`) so the Home's "Your impact" row appears;
3. writes `session.json` with 12 marks (the round Review badge) and one
   resumable session, so "Continue sorting" shows the photo it will next open.

Usage: python3 seed_state.py [--udid UDID]
"""
from __future__ import annotations

import argparse
import json
import os
import sqlite3
import subprocess

BUNDLE_ID = "com.zhangjinshuo.swipr"
DEFAULT_UDID = "71EAC83D-54D4-451A-AB32-74A8878C7869"
MARKS = 12
LIFETIME_DELETED = 860
LIFETIME_BYTES = 2_400_000_000


def container(udid: str) -> str:
    return subprocess.check_output(
        ["xcrun", "simctl", "get_app_container", udid, BUNDLE_ID, "data"],
        text=True,
    ).strip()


def photos_database(udid: str) -> str:
    home = os.path.expanduser("~")
    return os.path.join(
        home,
        "Library/Developer/CoreSimulator/Devices",
        udid,
        "data/Media/PhotoData/Photos.sqlite",
    )


def assets(udid: str):
    """(localIdentifier, creationDate, isVideo) newest first."""
    database = photos_database(udid)
    connection = sqlite3.connect(f"file:{database}?mode=ro", uri=True)
    rows = connection.execute(
        "SELECT ZUUID, ZDATECREATED, ZKIND FROM ZASSET ORDER BY ZDATECREATED DESC"
    ).fetchall()
    return [
        (f"{uuid}/L0/001", float(created), int(kind) == 1)
        for uuid, created, kind in rows
    ]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--udid", default=DEFAULT_UDID)
    args = parser.parse_args()

    rows = assets(args.udid)
    if len(rows) < MARKS + 1:
        raise SystemExit(f"only {len(rows)} assets in the library; seed more first")

    ids = [identifier for identifier, _, _ in rows]
    marks = ids[:MARKS]
    # The Continue thumbnail should be a photo, and not one that is already
    # marked, so pick the newest image outside the mark window.
    current = next(
        (identifier for identifier, _, is_video in rows[MARKS:] if not is_video),
        rows[MARKS][0],
    )
    updated = rows[0][1]

    state = {
        "schemaVersion": 4,
        "marks": marks,
        "session": {
            "currentAssetID": current,
            "currentAssetDate": updated,
            "direction": "older",
            "mode": "sequential",
            "decidedIDs": [],
            "keptIDs": [],
            "undoEntries": [],
            "filterCategories": [
                "screenshot",
                "livePhoto",
                "panorama",
                "otherPhoto",
                "video",
            ],
            "poolIDs": ids,
            "updatedAt": updated,
            "isFinished": False,
        },
        "updatedAt": updated,
    }
    statistics = {
        "currentSessionDeletedCount": 0,
        "currentSessionReclaimedBytes": 0,
        "lifetimeDeletedCount": LIFETIME_DELETED,
        "lifetimeReclaimedBytes": LIFETIME_BYTES,
        "lifetimeCompletedSessions": 12,
    }

    directory = os.path.join(container(args.udid), "Library/Application Support/SWIPR")
    os.makedirs(directory, exist_ok=True)
    with open(os.path.join(directory, "session.json"), "w") as handle:
        json.dump(state, handle)
    with open(os.path.join(directory, "statistics.json"), "w") as handle:
        json.dump(statistics, handle)

    print(f"seeded {len(marks)} marks and a session at {current} into {directory}")


if __name__ == "__main__":
    main()
