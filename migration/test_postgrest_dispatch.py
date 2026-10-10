import os
import psycopg2
import requests
import json

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

cur.execute("DELETE FROM dispatch_batches WHERE dispatch_id IN (SELECT id FROM dispatches WHERE material_code = 'TEST-PROD-A');")
cur.execute("DELETE FROM dispatches WHERE material_code = 'TEST-PROD-A';")
cur.execute("DELETE FROM batches WHERE material_code = 'TEST-PROD-A';")

cur.execute("""
    INSERT INTO batches (batch_no, material_code, description, received_quantity, available_quantity, uom, department, received_date)
    VALUES ('B001', 'TEST-PROD-A', 'Benchmark Product A', 100.0, 100.0, 'kg', 'Storage', CURRENT_DATE);
""")
conn.close()

# Call create_dispatch_fifo via PostgREST
url = 'https://japxiaxyabhhhclphbqr.supabase.co/rest/v1/rpc/create_dispatch_fifo'
headers = {
    'apikey': 'sb_publishable_mFHcuugJQo1XBVXxtt1c5Q_HIoCGFVa',
    'Authorization': 'Bearer sb_publishable_mFHcuugJQo1XBVXxtt1c5Q_HIoCGFVa',
    'Content-Type': 'application/json'
}
payload = {
    'p_dispatch': {
        'material_code': 'TEST-PROD-A',
        'product': 'Benchmark Product A',
        'quantity': 50,
        'units': 'kg',
        'location': 'Counter',
        'department': 'Dispatch',
        'date': '2026-10-02'
    },
    'p_idempotency_key': 'TEST-SAFEUPDATE-002'
}

res = requests.post(url, headers=headers, json=payload)
print('Status code:', res.status_code)
print('Response text:', res.text)
