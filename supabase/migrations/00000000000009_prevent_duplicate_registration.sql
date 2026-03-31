-- ============================================
-- SPEC-006: Prevent Duplicate Registration
-- Trigger to prevent same person registering twice in same tournament
-- ============================================

CREATE OR REPLACE FUNCTION prevent_duplicate_registration()
RETURNS TRIGGER AS $$
DECLARE
    v_category_tournament_id UUID;
    v_existing_count INTEGER;
BEGIN
    -- Get tournament_id from the category of the entry being registered to
    SELECT c.tournament_id INTO v_category_tournament_id
    FROM categories c
    JOIN tournament_entries te ON te.category_id = c.id
    WHERE te.id = NEW.entry_id;

    -- Check if person already has an active registration (non-cancelled) in this tournament
    SELECT COUNT(*) INTO v_existing_count
    FROM entry_members em
    JOIN tournament_entries te ON em.entry_id = te.id
    JOIN categories c ON te.category_id = c.id
    WHERE em.person_id = NEW.person_id
      AND c.tournament_id = v_category_tournament_id
      AND te.status != 'CANCELLED';

    IF v_existing_count > 0 THEN
        RAISE EXCEPTION 'Person % is already registered in this tournament', NEW.person_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger fires BEFORE INSERT on entry_members
DROP TRIGGER IF EXISTS trg_prevent_duplicate_registration ON entry_members;
CREATE TRIGGER trg_prevent_duplicate_registration
    BEFORE INSERT ON entry_members
    FOR EACH ROW
    EXECUTE FUNCTION prevent_duplicate_registration();
