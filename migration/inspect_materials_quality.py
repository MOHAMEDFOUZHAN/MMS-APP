import psycopg2
import json

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = 'mapleconnect2307'
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
cur = conn.cursor()

cur.execute("SELECT count(*) FROM materials WHERE unit IS NULL OR unit = ''")
null_units = cur.fetchone()[0]

cur.execute("SELECT count(*) FROM materials WHERE description IS NULL OR description = ''")
null_descs = cur.fetchone()[0]

cur.execute("SELECT count(*) FROM materials WHERE category IS NULL OR category = ''")
null_cats = cur.fetchone()[0]

cur.execute("SELECT count(*) FROM materials WHERE hsn_sac IS NULL OR hsn_sac = ''")
null_hsns = cur.fetchone()[0]

cur.execute("SELECT count(*) FROM materials WHERE grade IS NULL OR grade = ''")
null_grades = cur.fetchone()[0]

print(f"Total materials: 151")
print(f"Materials with NULL/empty unit: {null_units}")
print(f"Materials with NULL/empty description: {null_descs}")
print(f"Materials with NULL/empty category: {null_cats}")
print(f"Materials with NULL/empty hsn_sac: {null_hsns}")
print(f"Materials with NULL/empty grade: {null_grades}")

cur.execute("SELECT id, material_code, description, category, grade, unit, hsn_sac, reorder_level, quantity FROM materials LIMIT 10")
for r in cur.fetchall():
    print(r)

cur.close()
conn.close()
