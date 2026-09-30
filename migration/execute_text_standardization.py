import sys
import psycopg2
import json
import os

sys.stdout.reconfigure(encoding='utf-8')

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = 'mapleconnect2307'
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
cur = conn.cursor()

# 1. Backup materials table before applying cleanup
cur.execute("SELECT id, material_code, description, category, opening_stock, quantity, reorder_level, unit_price, unit, hsn_sac, grade FROM materials ORDER BY id")
rows = cur.fetchall()
cols = [desc[0] for desc in cur.description]
backup_data = [dict(zip(cols, [float(v) if hasattr(v, '__float__') and not isinstance(v, str) else str(v) if v is not None else None for v in r])) for r in rows]

backup_path = os.path.join(os.path.dirname(__file__), 'supabase_materials_pre_standardization_backup.json')
with open(backup_path, 'w', encoding='utf-8') as f:
    json.dump(backup_data, f, indent=2)
print(f"Backed up {len(backup_data)} materials to {backup_path}")

# 2. Apply Functions and Triggers
triggers_sql_path = os.path.join(os.path.dirname(__file__), '..', 'supabase', '02_text_standardization_triggers.sql')
with open(triggers_sql_path, 'r', encoding='utf-8') as f:
    sql_script = f.read()

cur.execute(sql_script)
conn.commit()
print("Installed normalization functions, functional indexes, and BEFORE INSERT/UPDATE triggers.")

# 3. Clean and Standardize Existing Materials Data
print("Executing standardization updates on existing materials...")

# Standardize units
cur.execute("UPDATE materials SET unit = 'PKT' WHERE unit IN ('packet', 'Pkt');")
cur.execute("UPDATE materials SET unit = UPPER(TRIM(unit));")

# Standardize categories
cur.execute("UPDATE materials SET category = 'CHOCOLATE' WHERE category IN ('chocolater', 'CHOCOLATER');")
cur.execute("UPDATE materials SET category = UPPER(REGEXP_REPLACE(TRIM(category), '\\s+', ' ', 'g'));")

# Standardize descriptions and codes
cur.execute("UPDATE materials SET description = UPPER(REGEXP_REPLACE(TRIM(description), '\\s+', ' ', 'g'));")
cur.execute("UPDATE materials SET material_code = UPPER(REGEXP_REPLACE(TRIM(material_code), '\\s+', '', 'g'));")
cur.execute("UPDATE materials SET grade = UPPER(REGEXP_REPLACE(TRIM(grade), '\\s+', ' ', 'g')) WHERE grade IS NOT NULL;")
cur.execute("UPDATE materials SET hsn_sac = UPPER(REGEXP_REPLACE(TRIM(hsn_sac), '\\s+', ' ', 'g')) WHERE hsn_sac IS NOT NULL;")

conn.commit()
print("Successfully committed text standardization updates.")

# 4. Verify post-cleanup state
cur.execute("SELECT count(*) FROM materials")
total = cur.fetchone()[0]

cur.execute("SELECT DISTINCT category FROM materials ORDER BY category")
cats = [r[0] for r in cur.fetchall()]

cur.execute("SELECT DISTINCT unit FROM materials ORDER BY unit")
units = [r[0] for r in cur.fetchall()]

cur.execute("SELECT count(*) FROM materials WHERE description != UPPER(description) OR description != TRIM(description)")
dirty_descs = cur.fetchone()[0]

print(f"\n--- VERIFICATION REPORT ---")
print(f"Total Materials in Supabase: {total}")
print(f"Standardized Categories ({len(cats)}): {cats}")
print(f"Standardized Units ({len(units)}): {units}")
print(f"Non-standard descriptions remaining: {dirty_descs}")

cur.close()
conn.close()
