import os
import psycopg2

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = os.environ["SUPABASE_DB_PASSWORD"]
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
conn.autocommit = True
cur = conn.cursor()

with open('supabase/08_owner_portal_security.sql', 'r', encoding='utf-8') as f:
    sql = f.read()

print("Applying 08_owner_portal_security.sql...")
cur.execute(sql)
print("Migration applied successfully!")

# Verify user_profiles
cur.execute("SELECT id, username, role, permissions FROM user_profiles WHERE username = 'owner' OR role = 'OWNER';")
print("Owner profile:", cur.fetchall())

# Test verify_owner_access function as owner
cur.execute("SELECT id FROM auth.users WHERE email = 'owner@benchmarkmms.com';")
owner_id = cur.fetchone()[0]

cur.execute(f"SET LOCAL \"request.jwt.claim.sub\" = '{owner_id}';")
cur.execute(f"SET LOCAL ROLE authenticated;")

cur.execute("SELECT verify_owner_access();")
print("Owner verification check:", cur.fetchone())

cur.execute("SELECT get_owner_dashboard_summary();")
summary = cur.fetchone()[0]
print("Dashboard summary keys:", list(summary.keys()))
print("KPI data:", summary.get('kpi'))
print("Today data:", summary.get('today'))

cur.close()
conn.close()
