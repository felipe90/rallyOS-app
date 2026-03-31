-- ============================================
-- SPEC-011: Community Feed
-- Enable RLS on community_feed and auto-generate events
-- ============================================

-- Enable RLS on community_feed
ALTER TABLE community_feed ENABLE ROW LEVEL SECURITY;

-- SELECT: All authenticated users can view feed
CREATE POLICY "Authenticated users can view feed"
ON community_feed FOR SELECT
USING (auth.role() = 'authenticated');

-- INSERT: Only staff can create manual entries (announcements)
CREATE POLICY "Staff can create feed entries"
ON community_feed FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM tournament_staff ts
        WHERE ts.tournament_id = community_feed.tournament_id
        AND ts.user_id = auth.uid()
    )
);

-- DELETE: Only organizers can delete feed entries
CREATE POLICY "Organizers can delete feed entries"
ON community_feed FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM tournament_staff ts
        WHERE ts.tournament_id = community_feed.tournament_id
        AND ts.user_id = auth.uid()
        AND ts.role = 'ORGANIZER'
    )
);

-- Function to auto-generate feed entries
CREATE OR REPLACE FUNCTION generate_feed_event()
RETURNS TRIGGER AS $$
DECLARE
    v_tournament_id UUID;
    v_payload JSONB;
BEGIN
    -- Determine tournament_id based on context
    IF TG_TABLE_NAME = 'tournament_entries' THEN
        SELECT c.tournament_id INTO v_tournament_id
        FROM categories c
        JOIN tournament_entries te ON te.category_id = c.id
        WHERE te.id = NEW.id;
        
        -- Entry registered event
        IF NEW.status = 'CONFIRMED' THEN
            INSERT INTO community_feed (tournament_id, event_type, payload_json)
            VALUES (v_tournament_id, 'ENTRY_REGISTERED', 
                jsonb_build_object(
                    'entry_id', NEW.id,
                    'display_name', NEW.display_name
                ));
        ELSIF NEW.status = 'CANCELLED' THEN
            INSERT INTO community_feed (tournament_id, event_type, payload_json)
            VALUES (v_tournament_id, 'ENTRY_CANCELLED',
                jsonb_build_object(
                    'entry_id', NEW.id,
                    'display_name', NEW.display_name
                ));
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for entry registration
DROP TRIGGER IF EXISTS trg_feed_entry_registered ON tournament_entries;
CREATE TRIGGER trg_feed_entry_registered
    AFTER INSERT OR UPDATE ON tournament_entries
    FOR EACH ROW
    EXECUTE FUNCTION generate_feed_event();
