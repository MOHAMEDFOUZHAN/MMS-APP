import os
import psycopg2
import json

conn = psycopg2.connect(
    host='aws-0-ap-northeast-1.pooler.supabase.com',
    port=5432,
    user='postgres.japxiaxyabhhhclphbqr',
    password=os.environ["SUPABASE_DB_PASSWORD"],
    dbname='postgres',
    connect_timeout=15
)
cur = conn.cursor()

# Test batch number generator
cur.execute("SELECT generate_storage_batch_number(DATE '2026-01-01'), generate_storage_batch_number(DATE '2026-10-01')")
print('Batch numbers generated:', cur.fetchall())

# Test preview for CARD-TEA-01
cur.execute("SELECT get_storage_dispatch_preview(NULL, 'CARD-TEA-01', 50)")
preview = cur.fetchone()[0]
print('Preview result for CARD-TEA-01:', json.dumps(preview, indent=2))

cur.close()
conn.close()
