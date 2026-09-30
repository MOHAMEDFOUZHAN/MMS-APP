-- Supabase Material Aliases Table (Section 27)
-- Configurable alias dictionary replacing hardcoded string corrections

CREATE TABLE IF NOT EXISTS public.material_aliases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alias_pattern TEXT NOT NULL UNIQUE,       -- Normalized lower-case OCR typo or vendor abbreviation
    canonical_text TEXT NOT NULL,              -- Standard canonical name
    material_code TEXT,                        -- Optional reference to materials(material_code)
    category TEXT,                             -- Category (TEA, PACKAGING, CONSUMABLE, SPICES, etc.)
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.material_aliases ENABLE ROW LEVEL SECURITY;

-- Allow read access to authenticated and service_role
CREATE POLICY "Allow read access to material_aliases"
    ON public.material_aliases
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- Allow insert/update to authenticated users
CREATE POLICY "Allow modification of material_aliases"
    ON public.material_aliases
    FOR ALL
    TO authenticated
    USING (true);

-- Seed initial proven aliases from Benchmark MMS domain dictionary
INSERT INTO public.material_aliases (alias_pattern, canonical_text, material_code, category)
VALUES
    ('buttefly', 'BUTTERFLY', NULL, 'PACKAGING'),
    ('kosherking napkin', 'KOSHER KING NAPKIN', '900', 'CONSUMABLE'),
    ('woodenspoonsmall', 'WOODEN SPOON SMALL', '901', 'CONSUMABLE'),
    ('woodenspoon', 'WOODEN SPOON', '901', 'CONSUMABLE'),
    ('petjar', 'PET JAR', '902', 'PACKAGING'),
    ('pet jar - 600ml', 'PET JAR - 500ML', '902', 'PACKAGING'),
    ('ldcover', 'LD COVER', '903', 'PACKAGING'),
    ('4ldcover', 'LD COVER', '903', 'PACKAGING'),
    ('st.pouch', 'ST. POUCH', '904', 'PACKAGING'),
    ('st.pouch brown', 'ST. POUCH BROWN', '904', 'PACKAGING'),
    ('collo tape', 'CELLO TAPE', '905', 'PACKAGING'),
    ('cellotape', 'CELLO TAPE', '905', 'PACKAGING'),
    ('collo', 'CELLO', '905', 'PACKAGING'),
    ('rown tape', 'BROWN TAPE', '907', 'PACKAGING'),
    ('paperstraw', 'PAPER STRAW', '908', 'CONSUMABLE'),
    ('rippletumbler', 'RIPPLE TUMBLER', '910', 'CONSUMABLE')
ON CONFLICT (alias_pattern) DO NOTHING;
