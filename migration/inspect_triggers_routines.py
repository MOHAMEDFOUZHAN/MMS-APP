import psycopg2

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = 'mapleconnect2307'
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
cur = conn.cursor()

cur.execute("""
SELECT 
    event_object_table, 
    trigger_name, 
    event_manipulation, 
    action_timing, 
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;
""")
triggers = cur.fetchall()
print(f"Triggers in public schema ({len(triggers)}):")
for t in triggers:
    print(t)

cur.execute("""
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
ORDER BY routine_name;
""")
routines = cur.fetchall()
print(f"\nRoutines in public schema ({len(routines)}):")
for r in routines:
    print(r)

cur.close()
conn.close()
