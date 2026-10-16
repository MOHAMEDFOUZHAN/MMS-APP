import os
import sys
import psycopg2

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = os.environ.get("SUPABASE_DB_PASSWORD", "mapleconnect2307")
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
conn.autocommit = True
cur = conn.cursor()

# 1. Update user_profiles role check constraint
print("Updating user_profiles constraint...")
cur.execute("""
ALTER TABLE public.user_profiles 
DROP CONSTRAINT IF EXISTS user_profiles_role_check;

ALTER TABLE public.user_profiles 
ADD CONSTRAINT user_profiles_role_check 
CHECK (role = ANY (ARRAY['OWNER'::text, 'ADMIN'::text, 'MANAGER'::text, 'STAFF'::text, 'VIEWER'::text, 'TEA_USER'::text, 'CHOCOLATE_USER'::text]));
""")

# 2. Check or create chocolate@benchmarkmms.com in auth.users
print("Provisioning auth.users for chocolate@benchmarkmms.com...")
cur.execute("SELECT id FROM auth.users WHERE email = 'chocolate@benchmarkmms.com';")
row = cur.fetchone()
if not row:
    cur.execute("""
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        email_change,
        email_change_token_new,
        recovery_token
    ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        gen_random_uuid(),
        'authenticated',
        'authenticated',
        'chocolate@benchmarkmms.com',
        crypt('cho123', gen_salt('bf')),
        NOW(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"full_name":"Benchmark Chocolate Department","role":"CHOCOLATE_USER","username":"chocolate"}'::jsonb,
        NOW(),
        NOW(),
        '', '', '', ''
    ) RETURNING id;
    """)
    uid = cur.fetchone()[0]
    print(f"Created user chocolate@benchmarkmms.com with id {uid}")
else:
    uid = row[0]
    cur.execute("""
    UPDATE auth.users 
    SET encrypted_password = crypt('cho123', gen_salt('bf')),
        email_confirmed_at = NOW(),
        raw_user_meta_data = '{"full_name":"Benchmark Chocolate Department","role":"CHOCOLATE_USER","username":"chocolate"}'::jsonb
    WHERE id = %s;
    """, (uid,))
    print(f"Updated user chocolate@benchmarkmms.com with id {uid}")

# 3. Ensure identity in auth.identities
cur.execute("SELECT id FROM auth.identities WHERE user_id = %s;", (uid,))
if not cur.fetchone():
    cur.execute("""
    INSERT INTO auth.identities (
        id,
        user_id,
        identity_data,
        provider,
        provider_id,
        last_sign_in_at,
        created_at,
        updated_at
    ) VALUES (
        gen_random_uuid(),
        %s,
        jsonb_build_object('sub', %s, 'email', 'chocolate@benchmarkmms.com'),
        'email',
        %s,
        NOW(),
        NOW(),
        NOW()
    );
    """, (uid, str(uid), str(uid)))
    print("Created identity for chocolate@benchmarkmms.com")

# 4. Upsert user_profiles
print("Upserting user_profiles for chocolate...")
cur.execute("""
INSERT INTO public.user_profiles (id, username, full_name, role, permissions, created_at, updated_at)
VALUES (%s, 'chocolate', 'Benchmark Chocolate Department', 'CHOCOLATE_USER', 
        ARRAY['chocolate.*', 'transfer.*', 'ocr.*', 'storage.*', 'dispatch.*', 'consign.*', 'notifications.view'], NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET
    username = EXCLUDED.username,
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    permissions = EXCLUDED.permissions,
    updated_at = NOW();
""", (uid,))
print("Upserted user_profiles for chocolate successfully")

# 5. Add rack_location column to batches and storage_products if not exists
print("Adding rack_location column...")
cur.execute("""
ALTER TABLE public.batches ADD COLUMN IF NOT EXISTS rack_location TEXT;
ALTER TABLE public.storage_products ADD COLUMN IF NOT EXISTS rack_location TEXT;
""")
print("Ensured rack_location column on batches and storage_products")

# 6. Add Helper Functions
cur.execute("""
CREATE OR REPLACE FUNCTION public.is_chocolate_user()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_role TEXT;
    v_username TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT role, username INTO v_role, v_username
    FROM public.user_profiles
    WHERE id = auth.uid();

    IF UPPER(COALESCE(v_role, '')) = 'CHOCOLATE_USER' OR LOWER(COALESCE(v_username, '')) IN ('chocolate', 'cho') THEN
        RETURN TRUE;
    END IF;

    SELECT (raw_user_meta_data->>'role'), (raw_user_meta_data->>'username') 
    INTO v_role, v_username
    FROM auth.users
    WHERE id = auth.uid();

    IF UPPER(COALESCE(v_role, '')) = 'CHOCOLATE_USER' OR LOWER(COALESCE(v_username, '')) IN ('chocolate', 'cho') THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;

CREATE OR REPLACE FUNCTION public.is_chocolate_product(p_code TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_clean_code TEXT;
    v_exists BOOLEAN := FALSE;
BEGIN
    v_clean_code := TRIM(COALESCE(p_code, ''));
    IF v_clean_code = '' THEN
        RETURN FALSE;
    END IF;

    -- Check canonical category in materials table
    SELECT TRUE INTO v_exists
    FROM public.materials
    WHERE LOWER(TRIM(material_code)) = LOWER(v_clean_code)
      AND UPPER(TRIM(category)) = 'CHOCOLATE'
    LIMIT 1;

    IF COALESCE(v_exists, FALSE) THEN
        RETURN TRUE;
    END IF;

    -- Check storage_products
    SELECT TRUE INTO v_exists
    FROM public.storage_products
    WHERE LOWER(TRIM(product_code)) = LOWER(v_clean_code)
      AND UPPER(TRIM(category)) = 'CHOCOLATE'
    LIMIT 1;

    IF COALESCE(v_exists, FALSE) THEN
        RETURN TRUE;
    END IF;

    -- Check batches
    SELECT TRUE INTO v_exists
    FROM public.batches
    WHERE (LOWER(TRIM(material_code)) = LOWER(v_clean_code) OR LOWER(TRIM(batch_no)) = LOWER(v_clean_code))
      AND UPPER(TRIM(category)) = 'CHOCOLATE'
    LIMIT 1;

    RETURN COALESCE(v_exists, FALSE);
END;
$$;
""")
print("Created is_chocolate_user() and is_chocolate_product() functions")

cur.close()
conn.close()
print("All database provisioning completed successfully!")
