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

cur.execute("""
CREATE TABLE IF NOT EXISTS public.app_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform VARCHAR(20) NOT NULL DEFAULT 'android',
    version_code INT NOT NULL,
    version_name VARCHAR(50) NOT NULL,
    apk_url TEXT NOT NULL,
    release_notes TEXT,
    is_mandatory BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
""")

cur.execute("""
ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public read access to app_versions" ON public.app_versions;
CREATE POLICY "Allow public read access to app_versions" 
    ON public.app_versions 
    FOR SELECT 
    TO public, anon, authenticated 
    USING (true);
""")

# Insert current version (code 7, name 1.0.6) as baseline
cur.execute("SELECT count(*) FROM public.app_versions WHERE platform = 'android';")
count = cur.fetchone()[0]
if count == 0:
    cur.execute("""
    INSERT INTO public.app_versions (platform, version_code, version_name, apk_url, release_notes, is_mandatory)
    VALUES ('android', 7, '1.0.6', '', 'Initial release', false);
    """)

conn.commit()
print("app_versions table initialized successfully! Rows:", count)
cur.close()
conn.close()
