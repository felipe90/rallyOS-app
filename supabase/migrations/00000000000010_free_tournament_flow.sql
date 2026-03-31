-- ============================================
-- SPEC-001: Free Tournament Flow
-- Add fee_amount to tournaments and auto-confirm for free tournaments
-- ============================================

-- Add fee_amount column to tournaments
ALTER TABLE tournaments 
ADD COLUMN IF NOT EXISTS fee_amount INTEGER DEFAULT 0;

-- Create function to auto-confirm entries for free tournaments
CREATE OR REPLACE FUNCTION auto_confirm_free_entry()
RETURNS TRIGGER AS $$
DECLARE
    v_fee_amount INTEGER;
BEGIN
    -- Get fee_amount from the tournament
    SELECT t.fee_amount INTO v_fee_amount
    FROM tournaments t
    JOIN categories c ON c.tournament_id = t.id
    WHERE c.id = NEW.category_id;

    -- If fee is 0 or NULL, auto-confirm the entry
    IF v_fee_amount IS NULL OR v_fee_amount = 0 THEN
        NEW.status := 'CONFIRMED';
    ELSE
        NEW.status := 'PENDING_PAYMENT';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger fires BEFORE INSERT on tournament_entries
DROP TRIGGER IF EXISTS trg_auto_confirm_free_entry ON tournament_entries;
CREATE TRIGGER trg_auto_confirm_free_entry
    BEFORE INSERT ON tournament_entries
    FOR EACH ROW
    EXECUTE FUNCTION auto_confirm_free_entry();
