import sys
import psycopg2
import re
from collections import defaultdict
from difflib import SequenceMatcher

sys.stdout.reconfigure(encoding='utf-8')

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = 'mapleconnect2307'
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
cur = conn.cursor()

def normalize_spaces(text):
    if not text:
        return ""
    return re.sub(r'\s+', ' ', str(text)).strip()

def normalize_text(text):
    if not text:
        return ""
    return normalize_spaces(text).upper()

def similarity(a, b):
    return SequenceMatcher(None, a.upper(), b.upper()).ratio()

cur.execute("""
SELECT id, material_code, description, category, unit, grade, hsn_sac
FROM materials
ORDER BY id;
""")
rows = cur.fetchall()

print(f"TOTAL RECORDS SCANNED: {len(rows)}")

# Analyze Categories
categories = [r[3] for r in rows if r[3]]
unique_raw_cats = sorted(list(set(categories)))

cat_case_diffs = []
cat_space_diffs = []
cat_norm_map = {}
for c in unique_raw_cats:
    norm = normalize_text(c)
    cat_norm_map[c] = norm
    if c != norm:
        if c.strip().upper() == norm and c != c.upper():
            cat_case_diffs.append((c, norm))
        elif re.sub(r'\s+', ' ', c).strip() != c:
            cat_space_diffs.append((c, norm))

# Fuzzy match across unique normalized categories
unique_norm_cats = sorted(list(set(cat_norm_map.values())))
cat_spelling_candidates = []
for i in range(len(unique_norm_cats)):
    for j in range(i + 1, len(unique_norm_cats)):
        c1 = unique_norm_cats[i]
        c2 = unique_norm_cats[j]
        sim = similarity(c1, c2)
        if 0.70 <= sim < 1.0 and abs(len(c1) - len(c2)) <= 3:
            cat_spelling_candidates.append((c1, c2, sim))

# Analyze UOM / Units
units = [r[4] for r in rows if r[4]]
unique_raw_units = sorted(list(set(units)))
unit_norm_map = {}
unit_diffs = []
for u in unique_raw_units:
    norm = normalize_text(u)
    unit_norm_map[u] = norm
    if u != norm:
        unit_diffs.append((u, norm))

# Analyze Grades
grades = [r[5] for r in rows if r[5]]
unique_raw_grades = sorted(list(set(grades)))
grade_norm_map = {}
grade_diffs = []
for g in unique_raw_grades:
    norm = normalize_text(g)
    grade_norm_map[g] = norm
    if g != norm:
        grade_diffs.append((g, norm))

# Analyze Descriptions
descriptions = [r[2] for r in rows if r[2]]
desc_diffs = []
desc_norm_map = {}
for d in set(descriptions):
    norm = normalize_text(d)
    desc_norm_map[d] = norm
    if d != norm:
        desc_diffs.append((d, norm))

# Fuzzy match across material descriptions to find similar/spelling variants
unique_norm_descs = sorted(list(set(desc_norm_map.values())))
desc_spelling_candidates = []
for i in range(len(unique_norm_descs)):
    for j in range(i + 1, len(unique_norm_descs)):
        d1 = unique_norm_descs[i]
        d2 = unique_norm_descs[j]
        sim = similarity(d1, d2)
        # Check if length is similar and similarity high
        if 0.82 <= sim < 1.0 and abs(len(d1) - len(d2)) <= 4:
            desc_spelling_candidates.append((d1, d2, sim))

# Summary
print(f"CASE DUPLICATES / VARIANTS:")
print(f"  • Categories needing uppercase: {len(cat_case_diffs)}")
print(f"  • Units needing uppercase: {len(unit_diffs)}")
print(f"  • Grades needing uppercase: {len(grade_diffs)}")
print(f"  • Descriptions needing uppercase/trim: {len(desc_diffs)}")
print(f"SPACE DUPLICATES: {len(cat_space_diffs)}")
print(f"POSSIBLE SPELLING DUPLICATES (Categories): {len(cat_spelling_candidates)}")
print(f"POSSIBLE SPELLING DUPLICATES (Descriptions): {len(desc_spelling_candidates)}")

print("\n--- CATEGORY AUDIT ---")
print(f"Distinct raw categories ({len(unique_raw_cats)}): {unique_raw_cats}")
for raw, norm in cat_norm_map.items():
    if raw != norm:
        print(f"  '{raw}' -> '{norm}' (Case/Space normalization)")

if cat_spelling_candidates:
    print("\nCategory spelling candidates for review:")
    for c1, c2, sim in cat_spelling_candidates:
        print(f"  '{c1}' vs '{c2}' (similarity: {sim:.2f})")

print("\n--- UOM / UNIT AUDIT ---")
print(f"Distinct raw units ({len(unique_raw_units)}): {unique_raw_units}")
for raw, norm in unit_norm_map.items():
    print(f"  '{raw}' -> '{norm}'")

print("\n--- GRADE AUDIT ---")
print(f"Distinct raw grades ({len(unique_raw_grades)}): {unique_raw_grades}")
for raw, norm in grade_norm_map.items():
    print(f"  '{raw}' -> '{norm}'")

print("\n--- SAMPLE DESCRIPTION NORMALIZATIONS (first 15) ---")
for raw, norm in list(desc_norm_map.items())[:15]:
    if raw != norm:
        print(f"  '{raw}' -> '{norm}'")

if desc_spelling_candidates:
    print(f"\nDescription spelling candidates for review ({len(desc_spelling_candidates)} found):")
    for d1, d2, sim in desc_spelling_candidates:
        print(f"  '{d1}' vs '{d2}' (sim: {sim:.2f})")

cur.close()
conn.close()
