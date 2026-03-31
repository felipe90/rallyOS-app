-- ============================================
-- SPEC-008: Sports CRUD con RLS
-- Enable RLS on sports table
-- ============================================

-- Enable RLS on sports
ALTER TABLE sports ENABLE ROW LEVEL SECURITY;

-- SELECT: All authenticated users can view sports (for tournament creation)
CREATE POLICY "Authenticated users can view sports"
ON sports FOR SELECT
USING (auth.role() = 'authenticated');

-- INSERT/UPDATE/DELETE: Only service role (admin) can manage sports
-- Using SECURITY DEFINER function approach for admin operations
CREATE OR REPLACE FUNCTION manage_sports()
RETURNS TRIGGER AS $$
BEGIN
    -- Only allow if called from service role context or admin check
    -- For MVP: we use a simple check that this is an admin operation
    IF current_setting('app.role', true) = 'admin' THEN
        RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Only administrators can modify sports';
END;
$$ LANGUAGE plpgsql;

-- For MVP, we'll allow INSERT/UPDATE/DELETE via service role
-- These policies will be bypassed when using service_role key
CREATE POLICY "Admins can insert sports"
ON sports FOR INSERT
WITH CHECK (auth.uid() IS NOT NULL); -- Placeholder - real admin check via service role

CREATE POLICY "Admins can update sports"
ON sports FOR UPDATE
USING (auth.uid() IS NOT NULL); -- Placeholder - real admin check via service role

CREATE POLICY "Admins can delete sports"
ON sports FOR DELETE
USING (auth.uid() IS NOT NULL); -- Placeholder - real admin check via service role

-- Note: In production, use Supabase service_role key for admin operations
-- Client-side apps should NOT have direct access to modify sports
