import psycopg2
import sqlite3
import json

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = 'mapleconnect2307'
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn_sb = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
cur_sb = conn_sb.cursor()

# Get all materials from Supabase
cur_sb.execute("SELECT id, material_code, description, category, grade, unit, hsn_sac, reorder_level, quantity, opening_stock FROM materials ORDER BY material_code")
sb_cols = [desc[0] for desc in cur_sb.description]
sb_materials = [dict(zip(sb_cols, row)) for row in cur_sb.fetchall()]

print(f"Supabase Materials Count: {len(sb_materials)}")

# Get all materials from SQLite
conn_sq = sqlite3.connect(r"d:\projects\MMS APP\BeanchMark-MMS\inventory - BeanchMark-MMS.db")
cur_sq = conn_sq.cursor()
cur_sq.execute("PRAGMA table_info(materials)")
sq_cols_info = cur_sq.fetchall()
print("SQLite materials columns:", [c[1] for c in sq_cols_info])

cur_sq.execute("SELECT * FROM materials")
sq_cols = [c[1] for c in sq_cols_info]
sq_materials = [dict(zip(sq_cols, row)) for row in cur_sq.fetchall()]
print(f"SQLite Materials Count: {len(sq_materials)}")

# SQLite duplicate codes:
from collections import defaultdict
sq_by_code = defaultdict(list)
for m in sq_materials:
    sq_by_code[str(m['material_code'])].append(m)

sq_dups = {k: v for k, v in sq_by_code.items() if len(v) > 1}
print(f"Number of distinct codes in SQLite with duplicates: {len(sq_dups)}")
total_dup_records = sum(len(v) for v in sq_dups.values())
print(f"Total duplicate records in SQLite: {total_dup_records}")
print(f"Unique distinct codes in SQLite: {len(sq_by_code)}")

sb_by_code = {str(m['material_code']): m for m in sb_materials}
print(f"Unique distinct codes in Supabase: {len(sb_by_code)}")

# Check codes in SQLite that are missing in Supabase
missing_in_sb = set(sq_by_code.keys()) - set(sb_by_code.keys())
print(f"Codes in SQLite missing in Supabase ({len(missing_in_sb)}):", sorted(list(missing_in_sb)))

# Check codes in Supabase missing in SQLite
missing_in_sq = set(sb_by_code.keys()) - set(sq_by_code.keys())
print(f"Codes in Supabase missing in SQLite ({len(missing_in_sq)}):", sorted(list(missing_in_sq)))

# Let's inspect some of the duplicate groups from SQLite
print("\nSample duplicate groups in SQLite:")
for code, group in list(sq_dups.items())[:10]:
    print(f"\n--- Code: {code} ({len(group)} records) ---")
    for item in group:
        print(f"  id={item.get('id')}, desc={item.get('description')}, cat={item.get('category')}, uom={item.get('unit')}, qty={item.get('quantity')}")
    if code in sb_by_code:
        sb_item = sb_by_code[code]
        print(f"  Current Supabase: id={sb_item.get('id')}, desc={sb_item.get('description')}, cat={sb_item.get('category')}, grade={sb_item.get('grade')}, uom={sb_item.get('uom')}, qty={sb_item.get('quantity')}")

conn_sb.close()
conn_sq.close()
