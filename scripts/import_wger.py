#!/usr/bin/env python3
"""
Bulk-import the wger.de exercise database into FitAI's local catalog.

wger.de ships exercises under CC-BY-SA 4.0 — attribution required, kept in
the app under Profile → About. Output is a single JSON file that
`ExerciseDatabase.swift` reads at runtime; the existing hardcoded ~55-entry
catalog stays as a fallback for names the import doesn't cover.

Usage:
    python3 scripts/import_wger.py [--limit 400] [--lang 2]

The wger API paginates at 100 per request; we follow `next` until we hit
--limit or run out. `--lang 2` is English; pass other codes per
https://wger.de/api/v2/language/.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Iterable

try:
    import urllib.request as _urlreq
    import urllib.parse as _urlparse
except ImportError:
    print("urllib unavailable; running on a non-CPython runtime?", file=sys.stderr)
    raise


WGER_BASE = "https://wger.de/api/v2"

# Map wger muscle IDs → FitAI muscle group labels. wger has ~25 muscles;
# we collapse to FitAI's working set so the picker chips line up.
WGER_MUSCLE_MAP = {
    1: "Biceps",
    2: "Shoulders",     # Anterior deltoid
    3: "Chest",         # Serratus anterior
    4: "Chest",         # Pectoralis major
    5: "Triceps",
    6: "Abdominals",    # Rectus abdominis
    7: "Calves",
    8: "Glutes",        # Gluteus maximus
    9: "Traps",
    10: "Quads",
    11: "Quads",        # Quadriceps femoris (alt id)
    12: "Back",         # Latissimus dorsi
    13: "Biceps",       # Brachialis
    14: "Forearms",
    15: "Hamstrings",
    16: "Back",         # Infraspinatus / Teres
    17: "Shoulders",    # Posterior deltoid
}

EQUIPMENT_HINTS = {
    1: "Barbell",
    2: "SZ Bar",
    3: "Dumbbell",
    4: "Gym Mat",
    5: "Swiss Ball",
    6: "Pull-up Bar",
    7: "None",
    8: "Bench",
    9: "Incline Bench",
    10: "Kettlebell",
    11: "Cable",
    12: "Machine",
}


def fetch(url: str) -> dict[str, Any]:
    req = _urlreq.Request(url, headers={"User-Agent": "FitAI-import/1.0"})
    with _urlreq.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def iter_exerciseinfo(language: int, limit: int) -> Iterable[dict[str, Any]]:
    url = f"{WGER_BASE}/exerciseinfo/?language={language}&limit=100&status=2"
    fetched = 0
    while url:
        page = fetch(url)
        for item in page.get("results", []):
            yield item
            fetched += 1
            if fetched >= limit:
                return
        url = page.get("next") or ""


def normalize(item: dict[str, Any]) -> dict[str, Any] | None:
    """Convert a wger exerciseinfo row into FitAI's canonical shape. Skip
    items missing a usable English name."""

    translations = item.get("translations") or []
    en = next((t for t in translations if t.get("language") == 2), None)
    if not en:
        return None

    name = (en.get("name") or "").strip()
    if not name:
        return None

    description = (en.get("description") or "").strip()
    notes = [n.get("comment", "") for n in en.get("notes") or [] if n.get("comment")]

    primary_ids = [m.get("id") for m in (item.get("muscles") or []) if m.get("id")]
    secondary_ids = [m.get("id") for m in (item.get("muscles_secondary") or []) if m.get("id")]
    primary = sorted({WGER_MUSCLE_MAP.get(mid) for mid in primary_ids if WGER_MUSCLE_MAP.get(mid)})
    secondary = sorted({WGER_MUSCLE_MAP.get(mid) for mid in secondary_ids if WGER_MUSCLE_MAP.get(mid)})
    primary = [m for m in primary if m]
    secondary = [m for m in secondary if m]

    equipment_ids = [e.get("id") for e in (item.get("equipment") or []) if e.get("id")]
    equipment = sorted({EQUIPMENT_HINTS.get(eid, "") for eid in equipment_ids if eid})
    equipment = [e for e in equipment if e]

    images = item.get("images") or []
    image_url = images[0].get("image") if images else ""

    return {
        "name": name,
        "instructions": [s.strip() for s in description.split(".") if s.strip()][:5],
        "tips": notes[:3],
        "primaryMuscles": primary,
        "secondaryMuscles": secondary,
        "equipment": equipment,
        "thumbnailURL": image_url or "",
        "videoURL": "",
        "frames": [],
        "source": "wger",
        "license": "CC-BY-SA 4.0",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__ or "")
    parser.add_argument("--limit", type=int, default=400, help="max exercises to import")
    parser.add_argument("--lang", type=int, default=2, help="wger language id (2 = English)")
    parser.add_argument(
        "--output",
        default="ios/FitAIPremiumFitnessApp/Resources/wger_exercises.json",
        help="output JSON path (FitAI bundle)",
    )
    args = parser.parse_args()

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)

    exercises: list[dict[str, Any]] = []
    seen_names: set[str] = set()
    print(f"Fetching up to {args.limit} exercises in language {args.lang}…")
    for raw in iter_exerciseinfo(language=args.lang, limit=args.limit):
        norm = normalize(raw)
        if not norm:
            continue
        if norm["name"].lower() in seen_names:
            continue
        seen_names.add(norm["name"].lower())
        exercises.append(norm)

    print(f"Imported {len(exercises)} unique exercises.")
    payload = {
        "version": 1,
        "license": "CC-BY-SA 4.0",
        "source": "https://wger.de/",
        "exercises": exercises,
    }
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {out}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
