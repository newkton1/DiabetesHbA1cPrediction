#!/usr/bin/env python3
"""
convert_mext_to_json.py

Converts the MEXT Standard Tables of Food Composition in Japan (八訂 2023)
main nutritional data Excel file into the JSON format used by Diabetes Feast.

Input:  20260327-mxt_kagsei-mext-000029402_02.xlsx  (main composition table)
Output: FoodDatabase_JP.json

All nutritional values are per 100g edible portion as published by MEXT.
Serving size is set to 100g by default; adjust individual items as needed.

Glycaemic index values are assigned by rule:
  - Items with known GI from published literature use that value.
  - Rice/noodle staples use the base GI for that carbohydrate.
  - Protein/fat-dominant items (fish, meat, eggs, oils) default to GI 0.
  - Items with no useful GI estimate default to GI 0 (no carbohydrate load).

Usage:
    python3 convert_mext_to_json.py \
        --input  20260327-mxt_kagsei-mext-000029402_02.xlsx \
        --output FoodDatabase_JP.json
"""

import argparse
import json
import re
import openpyxl


# ---------------------------------------------------------------------------
# MEXT food group code → Diabetes Feast category
# ---------------------------------------------------------------------------
GROUP_TO_CATEGORY = {
    "01": "Grains & Cereals",       # 穀類
    "02": "Side Dishes",            # いも及びでん粉類
    "03": "Flavorings",             # 砂糖及び甘味類
    "04": "Legumes & Beans",        # 豆類
    "05": "Nuts & Seeds",           # 種実類
    "06": "Vegetables",             # 野菜類
    "07": "Fruits",                 # 果実類
    "08": "Vegetables",             # きのこ類 (mushrooms → vegetables)
    "09": "Asian & Japanese",       # 藻類 (seaweed)
    "10": "Fish & Seafood",         # 魚介類
    "11": "Meat & Poultry",         # 肉類
    "12": "Dairy",                  # 卵類
    "13": "Dairy",                  # 乳類
    "14": "Flavorings",             # 油脂類
    "15": "Snacks & Sweets",        # 菓子類
    "16": "Beverages",              # し好飲料類
    "17": "Flavorings",             # 調味料及び香辛料類
    "18": "Frozen & Prepared Meals", # 調理済み流通食品類
}

# ---------------------------------------------------------------------------
# GI assignment rules
# Applied by keyword matching on the Japanese food name (食品名).
# Order matters — first match wins.
# Sources: International GI tables (Atkinson et al. 2008),
#          Japanese-specific GI studies (Sugiyama et al. 2003, Ito et al.).
# ---------------------------------------------------------------------------
GI_RULES = [
    # Rice varieties
    (["精白米", "うるち米", "白米"],          73),   # polished white rice (cooked)
    (["玄米"],                                55),   # brown rice
    (["もち米", "餅", "もち"],                80),   # glutinous rice / mochi
    (["おかゆ", "かゆ"],                      78),   # rice porridge / okayu
    (["赤飯"],                                77),   # sekihan (red rice)
    (["チャーハン", "炒飯"],                  70),   # fried rice
    (["すし飯", "酢飯", "寿司"],             72),   # sushi rice
    (["おにぎり"],                            74),   # onigiri

    # Noodles
    (["うどん"],                              55),   # udon
    (["そうめん", "素麺"],                    68),   # somen
    (["ひやむぎ", "冷麦"],                    68),   # hiyamugi
    (["そば", "蕎麦"],                        54),   # soba (buckwheat)
    (["中華めん", "ラーメン", "中華麺"],      68),   # ramen / Chinese noodles
    (["焼きそば"],                            67),   # yakisoba
    (["春雨", "はるさめ"],                    32),   # glass noodles
    (["しらたき", "こんにゃく"],              0),    # konjac / shirataki

    # Bread & wheat
    (["食パン", "ロールパン"],                75),   # white bread / rolls
    (["全粒粉"],                              52),   # wholegrain bread
    (["クロワッサン"],                        67),   # croissant
    (["ビスケット", "クラッカー"],            70),   # biscuits/crackers
    (["ホットケーキ", "パンケーキ"],          66),   # pancakes

    # Potato / starchy
    (["じゃがいも", "ジャガイモ"],            90),   # potato (boiled)
    (["さつまいも", "サツマイモ"],            55),   # sweet potato
    (["やまいも", "長いも"],                  65),   # yam
    (["片栗粉", "でん粉"],                    95),   # starch/katakuriko
    (["タロいも"],                            54),   # taro

    # Legumes (generally low GI)
    (["だいず", "大豆"],                      15),   # soy beans
    (["豆腐", "とうふ"],                      15),   # tofu
    (["納豆"],                                33),   # natto
    (["あずき", "小豆"],                      29),   # adzuki beans
    (["えだまめ", "枝豆"],                    18),   # edamame
    (["レンズまめ"],                          26),   # lentils

    # Fruit
    (["バナナ"],                              51),   # banana
    (["りんご", "リンゴ"],                   38),   # apple
    (["みかん", "オレンジ"],                 43),   # mandarin/orange
    (["ぶどう"],                              50),   # grape
    (["スイカ"],                              72),   # watermelon
    (["もも", "桃"],                          41),   # peach
    (["いちご", "苺"],                        40),   # strawberry

    # Dairy
    (["牛乳"],                                31),   # milk
    (["ヨーグルト"],                          36),   # yoghurt
    (["アイスクリーム"],                      57),   # ice cream

    # Zero/negligible GI — protein & fat dominant
    (["卵", "たまご"],                        0),    # eggs
    (["鶏肉", "とりにく", "チキン"],         0),    # chicken
    (["牛肉", "ぎゅうにく", "ビーフ"],       0),    # beef
    (["豚肉", "ぶたにく", "ポーク"],         0),    # pork
    (["魚", "さかな", "まぐろ", "さけ",
       "さば", "いわし", "あじ", "たら"],    0),    # fish
    (["油", "バター", "マーガリン",
       "マヨネーズ"],                         0),    # oils/fats
]

# ---------------------------------------------------------------------------
# Helper: parse a MEXT numeric cell value
# Returns float or None.
# MEXT uses: '-' (not detected/zero), 'Tr' (trace ~0), '(x)' (estimate),
#            '*' (calculated differently) — all treated as 0 or the number.
# ---------------------------------------------------------------------------
def parse_value(raw) -> float | None:
    if raw is None:
        return None
    if isinstance(raw, (int, float)):
        return float(raw)
    s = str(raw).strip()
    if s in ("-", "−", "－", ""):
        return 0.0
    if s.lower() == "tr":
        return 0.0
    if s == "*":
        return None           # skip — calculated value, use other column
    # Strip parentheses (estimated values are still usable)
    s = re.sub(r"[()（）]", "", s)
    try:
        return float(s)
    except ValueError:
        return None


def assign_gi(food_name: str, group_code: str) -> int:
    """Return an estimated GI for the food item."""
    for keywords, gi in GI_RULES:
        if any(kw in food_name for kw in keywords):
            return gi
    # Group-level defaults for items not matched above
    defaults = {
        "06": 0,   # vegetables — minimal GI
        "07": 50,  # fruits — moderate default
        "08": 0,   # mushrooms
        "09": 0,   # seaweed
        "10": 0,   # seafood
        "11": 0,   # meat
        "12": 0,   # eggs
        "13": 35,  # dairy
        "14": 0,   # oils
        "16": 0,   # beverages
    }
    return defaults.get(group_code, 0)


def convert(input_path: str, output_path: str):
    wb = openpyxl.load_workbook(input_path, data_only=True)
    ws = wb["表全体"]   # use the combined full sheet

    items = []
    skipped = 0

    # Data begins at row 13 (rows 1-12 are headers/metadata)
    for row in ws.iter_rows(min_row=13, values_only=True):
        group_code = str(row[0]).strip().zfill(2) if row[0] else None
        food_name  = str(row[3]).strip() if row[3] else None

        if not food_name or food_name in ("食品名", "単位", "成分識別子"):
            continue
        if group_code is None or group_code == "None":
            skipped += 1
            continue

        # Column indices (0-based):
        # 6  = ENERC_KCAL  calories
        # 9  = PROT-       protein
        # 12 = FAT-        fat
        # 15 = CHOAVL      available carbohydrates (mass basis)
        # 18 = FIB-        total dietary fibre
        calories = parse_value(row[6])
        protein  = parse_value(row[9])
        fat      = parse_value(row[12])
        carbs    = parse_value(row[15])
        fiber    = parse_value(row[18])

        # Skip rows where all key nutrients are missing (separator rows etc.)
        if all(v is None for v in [calories, protein, fat, carbs]):
            skipped += 1
            continue

        category = GROUP_TO_CATEGORY.get(group_code, "Asian & Japanese")
        gi       = assign_gi(food_name, group_code)

        item = {
            "name":          food_name,
            "category":      category,
            "servingSize":   100.0,
            "servingUnit":   "g",
            "calories":      round(calories or 0.0, 1),
            "carbohydrates": round(carbs   or 0.0, 1),
            "protein":       round(protein or 0.0, 1),
            "fat":           round(fat     or 0.0, 1),
            "fiber":         round(fiber   or 0.0, 1),
            "glycemicIndex": gi,
        }
        items.append(item)

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(items, f, ensure_ascii=False, indent=2)

    print(f"Done. {len(items)} items written to {output_path}")
    print(f"Skipped {skipped} blank/header rows.")

    # Summary stats
    gi_assigned = sum(1 for i in items if i["glycemicIndex"] > 0)
    gi_zero     = sum(1 for i in items if i["glycemicIndex"] == 0)
    print(f"GI > 0: {gi_assigned} items | GI = 0: {gi_zero} items")

    # Category breakdown
    from collections import Counter
    cats = Counter(i["category"] for i in items)
    print("\nCategory breakdown:")
    for cat, count in sorted(cats.items(), key=lambda x: -x[1]):
        print(f"  {count:4d}  {cat}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert MEXT food DB to Diabetes Feast JSON")
    parser.add_argument("--input",  required=True, help="Path to MEXT main Excel file (_02.xlsx)")
    parser.add_argument("--output", required=True, help="Output JSON path")
    args = parser.parse_args()
    convert(args.input, args.output)
