-- ==============================================================================
-- 06_PUSH_NOTIFICATIONS.SQL
-- Device Token Registry & Push Notification Infrastructure for Benchmark MMS
-- ==============================================================================

-- 1. Create device_tokens table
CREATE TABLE IF NOT EXISTS public.device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT UNIQUE NOT NULL,
    platform TEXT NOT NULL DEFAULT 'android' CHECK (platform IN ('android', 'ios', 'web')),
    device_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for quick lookups
CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON public.device_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_device_tokens_token ON public.device_tokens(token);

-- 2. Row Level Security (RLS)
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own device tokens" ON public.device_tokens;
CREATE POLICY "Users can view their own device tokens"
    ON public.device_tokens FOR SELECT
    USING (auth.uid() = user_id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Users can insert their own device tokens" ON public.device_tokens;
CREATE POLICY "Users can insert their own device tokens"
    ON public.device_tokens FOR INSERT
    WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role' OR user_id IS NULL);

DROP POLICY IF EXISTS "Users can update their own device tokens" ON public.device_tokens;
CREATE POLICY "Users can update their own device tokens"
    ON public.device_tokens FOR UPDATE
    USING (auth.uid() = user_id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Users can delete their own device tokens" ON public.device_tokens;
CREATE POLICY "Users can delete their own device tokens"
    ON public.device_tokens FOR DELETE
    USING (auth.uid() = user_id OR auth.role() = 'service_role');

-- 3. Trigger to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_device_tokens_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_device_tokens_updated_at ON public.device_tokens;
CREATE TRIGGER set_device_tokens_updated_at
    BEFORE UPDATE ON public.device_tokens
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_device_tokens_updated_at();

-- 4. Notification Dispatch Hook Comment
-- To trigger external FCM pushes via Supabase Edge Function:
-- Supabase Dashboard -> Database -> Webhooks -> Add Webhook
-- Table: notifications (INSERT)
-- URL: https://<project-ref>.supabase.co/functions/v1/send-push-notification
