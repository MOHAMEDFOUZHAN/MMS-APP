import psycopg2

conn = psycopg2.connect(
    host='aws-0-ap-northeast-1.pooler.supabase.com',
    port=5432,
    user='postgres.japxiaxyabhhhclphbqr',
    password='mapleconnect2307',
    dbname='postgres'
)
conn.autocommit = True
cur = conn.cursor()

emails = ['owner@benchmarkmms.com', 'admin@benchmarkmms.com']
for em in emails:
    cur.execute("SELECT id FROM auth.users WHERE email = %s", (em,))
    if cur.fetchone():
        print(f"User {em} already exists.")
        continue

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
        %s,
        crypt('admin123', gen_salt('bf')),
        NOW(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"full_name":"System Owner","role":"Owner"}'::jsonb,
        NOW(),
        NOW(),
        '',
        '',
        '',
        ''
    );
    """, (em,))
    print(f"User {em} provisioned successfully.")

cur.close()
conn.close()
