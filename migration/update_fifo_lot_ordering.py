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

# 1. Update create_transfer
cur.execute("SELECT prosrc FROM pg_proc WHERE proname = 'create_transfer'")
src = cur.fetchone()[0]

if 'ORDER BY lot_date ASC, id ASC' in src:
    new_src = src.replace('ORDER BY lot_date ASC, id ASC', 'ORDER BY COALESCE(received_at, created_at, lot_date::timestamptz) ASC, id ASC')
    cur.execute("""
    CREATE OR REPLACE FUNCTION create_transfer(
        p_transfer JSONB,
        p_idempotency_key TEXT DEFAULT NULL::TEXT
    ) RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $func$
    """ + new_src + """
    $func$;
    """)
    conn.commit()
    print("Updated create_transfer FIFO ordering to received_at ASC, id ASC!")
else:
    print("create_transfer already updated or pattern not found.")

# 2. Update update_transfer if exists
cur.execute("SELECT prosrc FROM pg_proc WHERE proname = 'update_transfer'")
row = cur.fetchone()
if row:
    src_upd = row[0]
    if 'ORDER BY lot_date ASC, id ASC' in src_upd:
        new_src_upd = src_upd.replace('ORDER BY lot_date ASC, id ASC', 'ORDER BY COALESCE(received_at, created_at, lot_date::timestamptz) ASC, id ASC')
        cur.execute("""
        CREATE OR REPLACE FUNCTION update_transfer(
            p_transfer_id BIGINT,
            p_transfer JSONB,
            p_idempotency_key TEXT DEFAULT NULL::TEXT
        ) RETURNS JSONB
        LANGUAGE plpgsql
        SECURITY DEFINER
        AS $func$
        """ + new_src_upd + """
        $func$;
        """)
        conn.commit()
        print("Updated update_transfer FIFO ordering to received_at ASC, id ASC!")

conn.close()
print("Migration completed successfully!")
