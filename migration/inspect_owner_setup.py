import os
import psycopg2

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = os.environ["SUPABASE_DB_PASSWORD"]
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
cur = conn.cursor()

print("--- CONSTRAINTS ON user_profiles ---")
cur.execute("""
SELECT conname, pg_get_constraintdef(c.oid)
FROM pg_constraint c
WHERE c.conrelid = 'user_profiles'::regclass;
""")
for r in cur.fetchall():
    print(r)

print("\n--- POLICIES ON user_profiles ---")
cur.execute("""
SELECT policyname, cmd, qual, with_check FROM pg_policies WHERE tablename = 'user_profiles';
""")
for r in cur.fetchall():
    print(r)

print("\n--- USERS IN user_profiles ---")
cur.execute("""
SELECT id, username, full_name, role, permissions FROM user_profiles;
""")
for r in cur.fetchall():
    print(r)

cur.close()
conn.close()
