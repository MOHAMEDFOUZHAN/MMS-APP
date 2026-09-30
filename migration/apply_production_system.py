import psycopg2
import sys
sys.stdout.reconfigure(encoding='utf-8')

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = 'mapleconnect2307'
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

print("Connecting to Supabase PostgreSQL...")
conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
conn.autocommit = True
cur = conn.cursor()

print("Applying supabase/04_production_system.sql...")
with open(r"d:\projects\MMS APP\supabase\04_production_system.sql", "r", encoding="utf-8") as f:
    sql = f.read()

cur.execute(sql)
print("Migration applied successfully!")

# Verify tables
cur.execute("SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;")
tables = [r[0] for r in cur.fetchall()]
print(f"\nActive tables in public schema ({len(tables)}):")
for t in tables:
    print(f"  • {t}")

# Check generated notifications
cur.execute("SELECT count(*), type, severity FROM notifications GROUP BY type, severity;")
notifs = cur.fetchall()
print(f"\nGenerated notifications summary:")
for n in notifs:
    print(f"  • {n[0]} notifications of type '{n[1]}' (Severity: {n[2]})")

# Check user profile
cur.execute("SELECT username, full_name, role, permissions FROM user_profiles;")
profiles = cur.fetchall()
print(f"\nUser profiles ({len(profiles)}):")
for p in profiles:
    print(f"  • Username: {p[0]}, Name: {p[1]}, Role: {p[2]}, Permissions Count: {len(p[3])}")

cur.close()
conn.close()
