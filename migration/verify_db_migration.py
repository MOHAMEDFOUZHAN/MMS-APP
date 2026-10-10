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
conn.autocommit = True
cur = conn.cursor()

# Test invoice_items columns
cur.execute("""
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_name = 'invoice_items' AND column_name IN ('lot_no', 'batch_no');
""")
print("invoice_items lot/batch columns:", cur.fetchall())

# Test material_lots columns
cur.execute("""
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_name = 'material_lots';
""")
print("material_lots columns:", [r[0] for r in cur.fetchall()])

# Test transfer_lot_allocations columns
cur.execute("""
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_name = 'transfer_lot_allocations';
""")
print("transfer_lot_allocations columns:", [r[0] for r in cur.fetchall()])

# Count initialized material_lots
cur.execute("SELECT count(*) FROM material_lots;")
print("material_lots row count:", cur.fetchone()[0])

conn.close()
