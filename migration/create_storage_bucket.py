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

# Create public bucket 'app-releases'
cur.execute("""
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('app-releases', 'app-releases', true, 104857600, ARRAY['application/vnd.android.package-archive', 'application/octet-stream'])
ON CONFLICT (id) DO UPDATE SET public = true;
""")

# Storage RLS policy for public read access
cur.execute("""
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
CREATE POLICY "Public Access" ON storage.objects
FOR SELECT TO public, anon, authenticated
USING (bucket_id = 'app-releases');
""")

# Storage RLS policy for uploads (anon or service)
cur.execute("""
DROP POLICY IF EXISTS "Allow Uploads" ON storage.objects;
CREATE POLICY "Allow Uploads" ON storage.objects
FOR INSERT TO public, anon, authenticated
WITH CHECK (bucket_id = 'app-releases');
""")

# Storage RLS policy for updates/overwrites
cur.execute("""
DROP POLICY IF EXISTS "Allow Updates" ON storage.objects;
CREATE POLICY "Allow Updates" ON storage.objects
FOR UPDATE TO public, anon, authenticated
USING (bucket_id = 'app-releases')
WITH CHECK (bucket_id = 'app-releases');
""")

conn.commit()
print("Storage bucket 'app-releases' created with public access & update policy!")
cur.close()
conn.close()
