import psycopg2
import sqlite3
import json
from collections import defaultdict

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = 'mapleconnect2307'
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn_sb = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
cur_sb = conn_sb.cursor()

# Backup current Supabase materials
cur_sb.execute("SELECT id, material_code, description, category, grade, unit, hsn_sac, reorder_level, quantity, opening_stock, purchase_date, expiry_date, lot_no, unit_price, last_updated FROM materials ORDER BY id")
cols = [desc[0] for desc in cur_sb.description]
sb_data = []
for row in cur_sb.fetchall():
    row_dict = {}
    for col, val in zip(cols, row):
        if hasattr(val, 'isoformat'):
            row_dict[col] = val.isoformat()
        elif hasattr(val, '__float__'):
            row_dict[col] = float(val)
        else:
            row_dict[col] = val
    sb_data.append(row_dict)

with open(r"d:\projects\MMS APP\migration\supabase_materials_backup.json", "w", encoding="utf-8") as f:
    json.dump(sb_data, f, indent=2)

print(f"Backed up {len(sb_data)} Supabase material records to supabase_materials_backup.json")

# Analyze duplicates in SQLite vs Supabase
conn_sq = sqlite3.connect(r"d:\projects\MMS APP\BeanchMark-MMS\inventory - BeanchMark-MMS.db")
cur_sq = conn_sq.cursor()
cur_sq.execute("SELECT * FROM materials")
sq_cols = [c[0] for c in cur_sq.description]
sq_materials = [dict(zip(sq_cols, row)) for row in cur_sq.fetchall()]

sq_by_code = defaultdict(list)
for m in sq_materials:
    sq_by_code[str(m['material_code'])].append(m)

sb_by_code = {str(m['material_code']): m for m in sb_data}

conflicts = []
for code, items in sq_by_code.items():
    if len(items) > 1:
        # Check if descriptions differ
        descriptions = set(i['description'].strip() if i['description'] else '' for i in items)
        categories = set(i['category'].strip() if i['category'] else '' for i in items)
        units = set(i['unit'].strip() if i['unit'] else '' for i in items)
        sb_item = sb_by_code.get(code)
        
        diff_desc = len(descriptions) > 1
        diff_cat = len(categories) > 1
        diff_unit = len(units) > 1
        
        if diff_desc or diff_cat or diff_unit:
            conflicts.append({
                'code': code,
                'diff_desc': diff_desc,
                'diff_cat': diff_cat,
                'diff_unit': diff_unit,
                'sqlite_items': items,
                'supabase_item': sb_item
            })

print(f"\nTotal duplicate groups in SQLite: {len([k for k, v in sq_by_code.items() if len(v) > 1])}")
print(f"Duplicate groups with differing metadata: {len(conflicts)}")

for c in conflicts:
    print(f"\nCode: {c['code']} (diff_desc={c['diff_desc']}, diff_cat={c['diff_cat']}, diff_unit={c['diff_unit']})")
    for it in c['sqlite_items']:
        print(f"   SQLite: desc='{it['description']}', cat='{it['category']}', unit='{it['unit']}', reorder={it['reorder_level']}")
    sb = c['supabase_item']
    print(f"   Supabase: desc='{sb['description']}', cat='{sb['category']}', grade='{sb['grade']}', unit='{sb['unit']}', reorder={sb['reorder_level']}")

conn_sb.close()
conn_sq.close()
