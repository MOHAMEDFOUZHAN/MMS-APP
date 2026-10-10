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

cur.execute("SHOW shared_preload_libraries;")
print("shared_preload_libraries:", cur.fetchall())

cur.execute("SELECT name, setting FROM pg_settings WHERE name ILIKE '%safeupdate%';")
print("safeupdate settings:", cur.fetchall())

# Test safeupdate in current session
try:
    cur.execute("SET safeupdate.enabled = 1;")
    print("safeupdate enabled successfully")
    cur.execute("CREATE TEMP TABLE t_test (id int);")
    cur.execute("DELETE FROM t_test;")
except Exception as e:
    print("Caught error with safeupdate:", e)

conn.close()
