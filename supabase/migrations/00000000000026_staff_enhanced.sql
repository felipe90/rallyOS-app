-- ============================================================
-- Migration: 00000000000026_staff_enhanced
-- Purpose:
--   1. Add staff_status ENUM for invitation workflow
--   2. Add invite_mode and invited_by columns to tournament_staff
--   3. Add expires_at for invitation expiration
-- ============================================================

BEGIN;

-- 1. CREATE staff_status ENUM
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'staff_status') THEN
        CREATE TYPE staff_status AS ENUM ('PENDING', 'ACTIVE', 'REJECTED', 'REVOKED');
    END IF;
END $$;

-- 2. ADD COLUMNS TO tournament_staff
ALTER TABLE tournament_staff 
ADD COLUMN IF NOT EXISTS status staff_status DEFAULT 'ACTIVE',
ADD COLUMN IF NOT EXISTS invite_mode BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS invited_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- 3. UPDATE existing records to ACTIVE status
UPDATE tournament_staff SET status = 'ACTIVE' WHERE status IS NULL;

-- 4. SET DEFAULT status for new inserts
ALTER TABLE tournament_staff 
ALTER COLUMN status SET DEFAULT 'ACTIVE';

-- 5. ADD INDEX for common queries
CREATE INDEX IF NOT EXISTS idx_tournament_staff_tournament_user 
ON tournament_staff(tournament_id, user_id);

CREATE INDEX IF NOT EXISTS idx_tournament_staff_status 
ON tournament_staff(status);

CREATE INDEX IF NOT EXISTS idx_tournament_staff_expires 
ON tournament_staff(expires_at) WHERE expires_at IS NOT NULL;

-- 6. ADD CONSTRAINT for unique active staff
-- Only one ACTIVE record per user per tournament
CREATE OR REPLACE FUNCTION check_single_active_staff()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'ACTIVE' THEN
        IF EXISTS (
            SELECT 1 FROM tournament_staff
            WHERE tournament_id = NEW.tournament_id
              AND user_id = NEW.user_id
              AND status = 'ACTIVE'
              AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000')
        ) THEN
            RAISE EXCEPTION 'User already has an active staff role in this tournament';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_single_active_staff ON tournament_staff;
CREATE TRIGGER trg_check_single_active_staff
BEFORE INSERT OR UPDATE ON tournament_staff
FOR EACH ROW
EXECUTE FUNCTION check_single_active_staff();

COMMIT;
