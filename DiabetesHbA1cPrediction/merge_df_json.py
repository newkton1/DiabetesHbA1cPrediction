#!/usr/bin/env python3
"""
merge_df_json.py
Merges all DiabetesFeast JSON export files in a folder into one
deduplicated file, keyed by the 'id' UUID field on each record.

Usage:
    python3 merge_df_json.py ~/Desktop/DFJSONBackups ~/Desktop/DiabetesFeast_Merged.json
"""

import json, os, glob, sys
from datetime import datetime, timezone

ARRAY_KEYS = [
    "glucoseReadings",
    "meals",
    "exerciseSessions",
    "hba1cPredictions",
    "healthConditions",
    "userProfile",
]

def merge(input_folder: str, output_path: str):
    files = sorted(glob.glob(os.path.join(input_folder, "*.json")))
    if not files:
        print(f"No JSON files found in {input_folder}")
        sys.exit(1)

    print(f"Found {len(files)} files to merge...")

    merged: dict[str, dict] = {key: {} for key in ARRAY_KEYS}  # id -> record
    app_version = "2.0"

    for path in files:
        fname = os.path.basename(path)
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:
            print(f"  SKIP {fname}: {e}")
            continue

        if "appVersion" in data:
            app_version = data["appVersion"]

        for key in ARRAY_KEYS:
            records = data.get(key, [])
            # userProfile may be a dict (single) or list
            if isinstance(records, dict):
                records = [records] if records else []
            before = len(merged[key])
            for rec in records:
                rec_id = rec.get("id")
                if rec_id and rec_id not in merged[key]:
                    merged[key][rec_id] = rec
            added = len(merged[key]) - before
            if added:
                print(f"  {fname}: +{added} {key}")

    # Build output
    output = {
        "appVersion": app_version,
        "exportDate": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z"),
    }
    totals = {}
    for key in ARRAY_KEYS:
        records = list(merged[key].values())
        output[key] = records
        totals[key] = len(records)

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"\nMerged output → {output_path}")
    for key, count in totals.items():
        print(f"  {key}: {count} unique records")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 merge_df_json.py <input_folder> <output_file>")
        sys.exit(1)
    merge(sys.argv[1], sys.argv[2])
