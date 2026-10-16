import psycopg2

def run_migration():
    conn = psycopg2.connect(
        host='aws-0-ap-northeast-1.pooler.supabase.com',
        port=5432,
        user='postgres.japxiaxyabhhhclphbqr',
        password='mapleconnect2307',
        dbname='postgres',
        connect_timeout=15
    )
    conn.autocommit = True
    cur = conn.cursor()

    sql = """
    CREATE TABLE IF NOT EXISTS public.tea_consumption_ledger (
        id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        date DATE NOT NULL DEFAULT CURRENT_DATE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        material_code TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT DEFAULT 'TEA',
        department TEXT DEFAULT 'TEA',
        unit TEXT DEFAULT 'kg',
        taken_qty NUMERIC(14, 3) NOT NULL DEFAULT 0.000,
        balance_qty NUMERIC(14, 3) NOT NULL DEFAULT 0.000,
        consumed_qty NUMERIC(14, 3) NOT NULL DEFAULT 0.000,
        operator_name TEXT DEFAULT '',
        shift TEXT DEFAULT 'Day Shift',
        status TEXT DEFAULT 'TAKEN',
        notes TEXT DEFAULT ''
    );

    CREATE INDEX IF NOT EXISTS idx_tea_consumption_date ON public.tea_consumption_ledger(date DESC);
    CREATE INDEX IF NOT EXISTS idx_tea_consumption_code ON public.tea_consumption_ledger(material_code);
    CREATE INDEX IF NOT EXISTS idx_tea_consumption_created_at ON public.tea_consumption_ledger(created_at DESC);

    ALTER TABLE public.tea_consumption_ledger ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Allow select all for tea_consumption_ledger" ON public.tea_consumption_ledger;
    CREATE POLICY "Allow select all for tea_consumption_ledger" 
    ON public.tea_consumption_ledger FOR SELECT TO authenticated USING (true);

    DROP POLICY IF EXISTS "Allow insert for tea_consumption_ledger" ON public.tea_consumption_ledger;
    CREATE POLICY "Allow insert for tea_consumption_ledger" 
    ON public.tea_consumption_ledger FOR INSERT TO authenticated WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow update for tea_consumption_ledger" ON public.tea_consumption_ledger;
    CREATE POLICY "Allow update for tea_consumption_ledger" 
    ON public.tea_consumption_ledger FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow delete for tea_consumption_ledger" ON public.tea_consumption_ledger;
    CREATE POLICY "Allow delete for tea_consumption_ledger" 
    ON public.tea_consumption_ledger FOR DELETE TO authenticated USING (true);

    DROP POLICY IF EXISTS "Allow anon select for tea_consumption_ledger" ON public.tea_consumption_ledger;
    CREATE POLICY "Allow anon select for tea_consumption_ledger" 
    ON public.tea_consumption_ledger FOR SELECT TO anon USING (true);

    DROP POLICY IF EXISTS "Allow anon insert for tea_consumption_ledger" ON public.tea_consumption_ledger;
    CREATE POLICY "Allow anon insert for tea_consumption_ledger" 
    ON public.tea_consumption_ledger FOR INSERT TO anon WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow anon update for tea_consumption_ledger" ON public.tea_consumption_ledger;
    CREATE POLICY "Allow anon update for tea_consumption_ledger" 
    ON public.tea_consumption_ledger FOR UPDATE TO anon USING (true) WITH CHECK (true);
    """

    cur.execute(sql)
    print("Migration successful! Table tea_consumption_ledger created/verified.")
    cur.close()
    conn.close()

if __name__ == '__main__':
    run_migration()
