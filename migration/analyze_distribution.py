import psycopg2
import sys
import json
from collections import Counter

sys.stdout.reconfigure(encoding='utf-8')

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = 'mapleconnect2307'
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
cur = conn.cursor()

cur.execute("SELECT id, material_code, description, category, unit, grade FROM materials ORDER BY id")
records = cur.fetchall()

print("Category distribution:")
cat_counts = Counter(r[3] for r in records)
for cat, cnt in sorted(cat_counts.items(), key=lambda x: -x[1]):
    print(f"  {repr(cat)}: {cnt} items")

print("\nUnit distribution:")
unit_counts = Counter(r[4] for r in records)
for u, cnt in sorted(unit_counts.items(), key=lambda x: -x[1]):
    print(f"  {repr(u)}: {cnt} items")

print("\nGrade distribution:")
grade_counts = Counter(r[5] for r in records)
for g, cnt in sorted(grade_counts.items(), key=lambda x: -x[1]):
    print(f"  {repr(g)}: {cnt} items")

cur.close()
conn.close()
