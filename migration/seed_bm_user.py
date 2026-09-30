import psycopg2
import requests

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = 'mapleconnect2307'
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
conn.autocommit = True
cur = conn.cursor()

# Check or create user bm@benchmarkmms.com
cur.execute("SELECT id FROM auth.users WHERE email = 'bm@benchmarkmms.com';")
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
        'bm@benchmarkmms.com',
        crypt('2307', gen_salt('bf')),
        NOW(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"full_name":"Benchmark Manager","role":"ADMIN","username":"bm"}'::jsonb,
        NOW(),
        NOW(),
        '',
        '',
        '',
        ''
    ) RETURNING id;
    """)
    uid = cur.fetchone()[0]
    print(f"Created bm@benchmarkmms.com with id: {uid}")
else:
    uid = row[0]
    cur.execute("""
    UPDATE auth.users 
    SET encrypted_password = crypt('2307', gen_salt('bf')),
        email_confirmed_at = NOW(),
        raw_user_meta_data = '{"full_name":"Benchmark Manager","role":"ADMIN","username":"bm"}'::jsonb
    WHERE id = %s;
    """, (uid,))
    print(f"Updated password to 2307 for bm@benchmarkmms.com ({uid})")

# Ensure identity
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
        jsonb_build_object('sub', %s, 'email', 'bm@benchmarkmms.com'),
        'email',
        %s,
        NOW(),
        NOW(),
        NOW()
    );
    """, (uid, str(uid), str(uid)))
    print("Created identity for bm@benchmarkmms.com")

cur.close()
conn.close()

# Test Supabase Auth signInWithPassword via REST API
SUPABASE_URL = "https://japxiaxyabhhhclphbqr.supabase.co"
ANON_KEY = "sb_publishable_mFHcuugJQo1XBVXxtt1c5Q_HIoCGFVa"

login_url = f"{SUPABASE_URL}/auth/v1/token?grant_type=password"
headers = {
    "apikey": ANON_KEY,
    "Content-Type": "application/json"
}
payload = {
    "email": "bm@benchmarkmms.com",
    "password": "2307"
}
resp = requests.post(login_url, json=payload, headers=headers)
print("Auth Login Test Status:", resp.status_code)
if resp.status_code == 200:
    data = resp.json()
    print("Successfully logged in! Access token received.")
    print("User ID:", data.get('user', {}).get('id'))
    print("User Email:", data.get('user', {}).get('email'))
else:
    print("Login failed:", resp.text)
