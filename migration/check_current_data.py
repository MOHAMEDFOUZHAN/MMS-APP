import os
import psycopg2

conn = psycopg2.connect(
    host='aws-0-ap-northeast-1.pooler.supabase.com',
    port=5432,
    user='postgres.japxiaxyabhhhclphbqr',
    password=os.environ["SUPABASE_DB_PASSWORD"],
    dbname='postgres',
    connect_timeout=15
)
cur = conn.cursor()

for tbl in ['invoices', 'invoice_items', 'materials', 'transfers', 'batches']:
    cur.execute(f"SELECT count(*) FROM {tbl};")
    cnt = cur.fetchone()[0]
    print(f"{tbl}: {cnt} rows")

cur.execute("SELECT id, material_code, description, quantity, lot_no, unit FROM materials WHERE quantity > 0 LIMIT 5;")
print("\nSample materials with stock > 0:")
for r in cur.fetchall():
    print(r)

cur.execute("SELECT id, invoice_id, material, quantity, batch_no FROM invoice_items LIMIT 5;")
print("\nSample invoice_items:")
for r in cur.fetchall():
    print(r)

conn.close()
