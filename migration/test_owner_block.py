import psycopg2

conn = psycopg2.connect(
    host='aws-0-ap-northeast-1.pooler.supabase.com',
    port=5432,
    user='postgres.japxiaxyabhhhclphbqr',
    password='mapleconnect2307',
    dbname='postgres',
    connect_timeout=15
)
cur = conn.cursor()
cur.execute("SELECT id FROM auth.users WHERE email = 'owner@benchmarkmms.com'")
owner_id = cur.fetchone()[0]

cur.execute(f"SET LOCAL \"request.jwt.claim.sub\" = '{owner_id}';")
cur.execute("SET LOCAL ROLE authenticated;")

try:
    cur.execute("UPDATE materials SET quantity = 999 WHERE material_code = '1';")
    print("FAILURE: Owner update was permitted!")
except Exception as e:
    print("SUCCESS: Owner update strictly rejected by backend trigger:")
    print(" ", e)

conn.rollback()

# Now test Admin user
cur.execute("SELECT id FROM auth.users WHERE email = 'admin@benchmarkmms.com'")
admin_id = cur.fetchone()[0]
cur.execute(f"SET LOCAL \"request.jwt.claim.sub\" = '{admin_id}';")
cur.execute("SET LOCAL ROLE authenticated;")

try:
    # Update to same quantity just to test permission
    cur.execute("UPDATE materials SET quantity = quantity WHERE material_code = '1';")
    print("SUCCESS: Admin update is permitted normally.")
except Exception as e:
    print("FAILURE: Admin update was blocked:", e)

conn.rollback()
cur.close()
conn.close()
