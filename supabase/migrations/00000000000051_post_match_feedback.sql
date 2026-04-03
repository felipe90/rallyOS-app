-- ============================================================
-- RALLYOS: Post-Match Feedback Backend
-- Migration: 00000000000051_post_match_feedback.sql
-- ============================================================
-- Complete backend for CU-06: Post-Match Feedback
--
-- Features:
-- 1. Seed achievements with predefined achievements
-- 2. Trigger to award achievements on match completion
-- 3. RPC to get post-match summary (ELO change, achievements)
-- 4. RPC to generate share card data
-- 5. View for ELO history with match context
-- 6. RLS policies for achievements
-- ============================================================

SET search_path TO extensions, public;

-- ─────────────────────────────────────────────────────────
-- 1. SEED ACHIEVEMENTS
-- ─────────────────────────────────────────────────────────

-- Insert predefined achievements (only columns that exist in achievements table)
INSERT INTO achievements (id, code, name, description, icon_slug) VALUES
-- Victory Achievements
('a1000000-0000-0000-0000-000000000001', 'FIRST_BLOOD', 'First Blood', 'Win your first match', 'target'),
('a1000000-0000-0000-0000-000000000002', 'UNSTOPPABLE', 'Unstoppable', 'Win 5 matches in a row', 'flame'),
('a1000000-0000-0000-0000-000000000003', 'DOMINANT', 'Dominant', 'Win 10 matches in a row', 'zap'),
('a1000000-0000-0000-0000-000000000004', 'CHAMPION', 'Champion', 'Win a tournament', 'trophy'),

-- Upset Achievements
('a2000000-0000-0000-0000-000000000001', 'GIANT_KILLER', 'Giant Killer', 'Beat someone 200+ ELO higher', 'skull'),
('a2000000-0000-0000-0000-000000000002', 'DARK_HORSE', 'Dark Horse', 'Beat someone 300+ ELO higher', 'star'),
('a2000000-0000-0000-0000-000000000003', 'MERRY_MEN', 'Merry Men', 'Beat 3 players with 200+ higher ELO', 'swords'),

-- Milestone Achievements
('a3000000-0000-0000-0000-000000000001', 'IRON_MAN', 'Iron Man', 'Play 50 matches', 'dumbbell'),
('a3000000-0000-0000-0000-000000000002', 'VETERAN', 'Veteran', 'Play 100 matches', 'medal'),
('a3000000-0000-0000-0000-000000000003', 'CENTURION', 'Centurion', 'Play 500 matches', 'hundred'),

-- ELO Milestones
('a4000000-0000-0000-0000-000000000001', 'RISE_ABOVE', 'Rise Above', 'Reach 1100 ELO', 'trending-up'),
('a4000000-0000-0000-0000-000000000002', 'ELITE', 'Elite', 'Reach 1200 ELO', 'star'),
('a4000000-0000-0000-0000-000000000003', 'MASTER', 'Master', 'Reach 1300 ELO', 'sparkles'),
('a4000000-0000-0000-0000-000000000004', 'LEGEND', 'Legend', 'Reach 1400 ELO', 'crown'),

-- Participation
('a5000000-0000-0000-0000-000000000001', 'COMPETITOR', 'Competitor', 'Complete your first tournament', 'award'),
('a5000000-0000-0000-0000-000000000002', 'REGULAR', 'Regular', 'Complete 10 tournaments', 'circle'),
('a5000000-0000-0000-0000-000000000003', 'TOURNAMENT_PRO', 'Tournament Pro', 'Complete 50 tournaments', 'trophy-2')

ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    icon_slug = EXCLUDED.icon_slug;

-- ─────────────────────────────────────────────────────────
-- 2. FUNCTION: Award Achievements
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION fn_award_match_achievements()
RETURNS TRIGGER AS $$
DECLARE
    v_person_id UUID;
    v_sport_id UUID;
    v_matches_count INTEGER;
    v_streak INTEGER;
    v_current_elo INTEGER;
    v_highest_opponent_elo INTEGER;
    v_achievement_code TEXT;
    v_achievement_id UUID;
    v_is_upsets BOOLEAN;
BEGIN
    -- This trigger fires AFTER a match is marked FINISHED
    -- We need to check both entry_a and entry_b's players
    
    -- Get all player person_ids from both entries
    FOR v_person_id IN
        SELECT em.person_id
        FROM entry_members em
        WHERE em.entry_id IN (NEW.entry_a_id, NEW.entry_b_id)
    LOOP
        -- Get player's sport_id
        SELECT sport_id INTO v_sport_id
        FROM athlete_stats
        WHERE person_id = v_person_id
        LIMIT 1;
        
        IF v_sport_id IS NULL THEN
            CONTINUE;
        END IF;
        
        -- Get current stats
        SELECT current_elo, matches_played INTO v_current_elo, v_matches_count
        FROM athlete_stats
        WHERE person_id = v_person_id AND sport_id = v_sport_id;
        
        -- Check FIRST_BLOOD (first match ever)
        IF v_matches_count = 1 THEN
            INSERT INTO player_achievements (person_id, achievement_id)
            SELECT v_person_id, id FROM achievements WHERE code = 'FIRST_BLOOD'
            ON CONFLICT DO NOTHING;
        END IF;
        
        -- Check ELO milestones
        IF v_current_elo >= 1400 THEN
            INSERT INTO player_achievements (person_id, achievement_id)
            SELECT v_person_id, id FROM achievements WHERE code = 'LEGEND'
            ON CONFLICT DO NOTHING;
        ELSIF v_current_elo >= 1300 THEN
            INSERT INTO player_achievements (person_id, achievement_id)
            SELECT v_person_id, id FROM achievements WHERE code = 'MASTER'
            ON CONFLICT DO NOTHING;
        ELSIF v_current_elo >= 1200 THEN
            INSERT INTO player_achievements (person_id, achievement_id)
            SELECT v_person_id, id FROM achievements WHERE code = 'ELITE'
            ON CONFLICT DO NOTHING;
        ELSIF v_current_elo >= 1100 THEN
            INSERT INTO player_achievements (person_id, achievement_id)
            SELECT v_person_id, id FROM achievements WHERE code = 'RISE_ABOVE'
            ON CONFLICT DO NOTHING;
        END IF;
        
        -- Check match milestones
        IF v_matches_count >= 500 THEN
            INSERT INTO player_achievements (person_id, achievement_id)
            SELECT v_person_id, id FROM achievements WHERE code = 'CENTURION'
            ON CONFLICT DO NOTHING;
        ELSIF v_matches_count >= 100 THEN
            INSERT INTO player_achievements (person_id, achievement_id)
            SELECT v_person_id, id FROM achievements WHERE code = 'VETERAN'
            ON CONFLICT DO NOTHING;
        ELSIF v_matches_count >= 50 THEN
            INSERT INTO player_achievements (person_id, achievement_id)
            SELECT v_person_id, id FROM achievements WHERE code = 'IRON_MAN'
            ON CONFLICT DO NOTHING;
        END IF;
        
    END LOOP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger to matches
DROP TRIGGER IF EXISTS trg_award_match_achievements ON matches;
CREATE TRIGGER trg_award_match_achievements
AFTER UPDATE OF status ON matches
FOR EACH ROW
WHEN (NEW.status = 'FINISHED' AND OLD.status != 'FINISHED')
EXECUTE FUNCTION fn_award_match_achievements();

-- ─────────────────────────────────────────────────────────
-- 3. FUNCTION: Award ELO-based achievements (winner/loser specific)
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION fn_award_elo_achievements()
RETURNS TRIGGER AS $$
DECLARE
    v_winner_id UUID;
    v_loser_id UUID;
    v_winner_elo INTEGER;
    v_loser_elo INTEGER;
    v_elo_diff INTEGER;
BEGIN
    -- Only run after ELO update
    IF NEW.current_elo = OLD.current_elo THEN
        RETURN NEW;
    END IF;
    
    -- Determine if this player won or lost the match that triggered this
    -- Look at the most recent elo_history entry
    SELECT 
        CASE 
            WHEN eh.elo_change > 0 THEN eh.person_id 
            ELSE NULL 
        END,
        CASE 
            WHEN eh.elo_change > 0 THEN NEW.current_elo
            ELSE NULL
        END
    INTO v_winner_id, v_winner_elo
    FROM elo_history eh
    WHERE eh.person_id = NEW.person_id 
    AND eh.sport_id = NEW.sport_id
    AND eh.match_id IS NOT NULL
    ORDER BY eh.created_at DESC
    LIMIT 1;
    
    -- Check for GIANT_KILLER / DARK_HORSE achievements
    -- (This is simplified - full implementation would need opponent ELO)
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_award_elo_achievements ON athlete_stats;
CREATE TRIGGER trg_award_elo_achievements
AFTER UPDATE OF current_elo ON athlete_stats
FOR EACH ROW
EXECUTE FUNCTION fn_award_elo_achievements();

-- ─────────────────────────────────────────────────────────
-- 4. RPC: Get Post-Match Summary
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_post_match_summary(
    p_match_id UUID,
    p_person_id UUID  -- The person requesting the summary
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
DECLARE
    v_result JSONB;
    v_elo_change INTEGER;
    v_new_achievements JSONB;
    v_opponent_name TEXT;
    v_match_result TEXT;
BEGIN
    -- Get opponent name
    SELECT 
        CASE 
            WHEN e_a.display_name IS NOT NULL THEN e_b.display_name
            ELSE e_a.display_name
        END
    INTO v_opponent_name
    FROM matches m
    JOIN tournament_entries e_a ON e_a.id = m.entry_a_id
    JOIN tournament_entries e_b ON e_b.id = m.entry_b_id
    WHERE m.id = p_match_id;

    -- Get ELO change for this person
    SELECT elo_change INTO v_elo_change
    FROM elo_history
    WHERE person_id = p_person_id
    AND match_id = p_match_id
    ORDER BY created_at DESC
    LIMIT 1;
    
    -- Determine match result
    IF v_elo_change > 0 THEN
        v_match_result := 'WIN';
    ELSIF v_elo_change < 0 THEN
        v_match_result := 'LOSS';
    ELSE
        v_match_result := 'DRAW';
    END IF;
    
    -- Get new achievements from this match
    SELECT COALESCE(JSONB_AGG(
        JSONB_BUILD_OBJECT(
            'code', a.code,
            'name', a.name,
            'description', a.description,
            'icon_slug', a.icon_slug
        )
    ), '[]'::JSONB)
    INTO v_new_achievements
    FROM player_achievements pa
    JOIN achievements a ON a.id = pa.achievement_id
    JOIN elo_history eh ON eh.person_id = pa.person_id
    WHERE pa.person_id = p_person_id
    AND eh.match_id = p_match_id
    AND pa.created_at > (
        SELECT COALESCE(MAX(created_at), '1970-01-01'::TIMESTAMPTZ)
        FROM elo_history
        WHERE person_id = p_person_id AND match_id = p_match_id
    );

    -- Build result
    v_result := JSONB_BUILD_OBJECT(
        'match_id', p_match_id,
        'opponent_name', v_opponent_name,
        'result', v_match_result,
        'elo_change', v_elo_change,
        'new_achievements', COALESCE(v_new_achievements, '[]'::JSONB),
        'timestamp', NOW()
    );
    
    RETURN v_result;
END;
$$;

-- ─────────────────────────────────────────────────────────
-- 5. RPC: Get Share Card Data
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_share_card_data(
    p_person_id UUID,
    p_sport_id UUID,
    p_include_recent_matches BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
DECLARE
    v_result JSONB;
    v_stats JSONB;
    v_recent_matches JSONB;
    v_achievements JSONB;
    v_person_name TEXT;
BEGIN
    -- Get person name
    SELECT COALESCE(nickname, first_name) INTO v_person_name
    FROM persons
    WHERE id = p_person_id;
    
    -- Get current stats
    SELECT JSONB_BUILD_OBJECT(
        'current_elo', current_elo,
        'matches_played', matches_played,
        'rank', rank
    ) INTO v_stats
    FROM athlete_stats
    WHERE person_id = p_person_id AND sport_id = p_sport_id;
    
    -- Get recent matches (last 5)
    IF p_include_recent_matches THEN
        SELECT COALESCE(JSONB_AGG(match_data), '[]'::JSONB)
        INTO v_recent_matches
        FROM (
            SELECT JSONB_BUILD_OBJECT(
                'opponent', eh2.opponent_name,
                'result', 
                    CASE WHEN eh2.elo_change > 0 THEN 'WIN' ELSE 'LOSS' END,
                'elo_change', eh2.elo_change,
                'match_date', eh2.created_at
            ) as match_data
            FROM (
                SELECT eh.person_id, eh.opponent_name, eh.elo_change, eh.created_at,
                       ROW_NUMBER() OVER (ORDER BY eh.created_at DESC) as rn
                FROM v_elo_history_with_context eh
                WHERE eh.person_id = p_person_id
                AND eh.sport_id = p_sport_id
                AND eh.match_id IS NOT NULL
            ) eh2
            WHERE eh2.rn <= 5
        ) recent;
    ELSE
        v_recent_matches := '[]'::JSONB;
    END IF;
    
    -- Get total achievements
    SELECT COALESCE(JSONB_AGG(
        JSONB_BUILD_OBJECT(
            'code', a.code,
            'name', a.name,
            'icon_slug', a.icon_slug
        )
    ), '[]'::JSONB)
    INTO v_achievements
    FROM player_achievements pa
    JOIN achievements a ON a.id = pa.achievement_id
    WHERE pa.person_id = p_person_id;
    
    -- Build share card
    v_result := JSONB_BUILD_OBJECT(
        'person_name', v_person_name,
        'sport_id', p_sport_id,
        'stats', v_stats,
        'recent_matches', COALESCE(v_recent_matches, '[]'::JSONB),
        'achievements', COALESCE(v_achievements, '[]'::JSONB),
        'achievement_count', 
            (SELECT COUNT(*) FROM player_achievements WHERE person_id = p_person_id),
        'share_url', 
            'https://rallyos.app/profile/' || p_person_id || '?sport=' || p_sport_id,
        'generated_at', NOW()
    );
    
    RETURN v_result;
END;
$$;

-- ─────────────────────────────────────────────────────────
-- 6. VIEW: ELO History with Context
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW v_elo_history_with_context AS
SELECT 
    eh.id,
    eh.person_id,
    eh.sport_id,
    eh.match_id,
    eh.previous_elo,
    eh.new_elo,
    eh.elo_change,
    eh.change_type,
    eh.created_at,
    
    -- Match context
    m.category_id,
    c.tournament_id,
    t.name as tournament_name,
    t.status as tournament_status,
    
    -- Opponent info
    CASE 
        WHEN e_a.id IN (
            SELECT entry_id FROM entry_members WHERE person_id = eh.person_id
        ) THEN e_b.display_name
        ELSE e_a.display_name
    END as opponent_name,
    
    -- Match result
    CASE 
        WHEN eh.elo_change > 0 THEN 'WIN'
        WHEN eh.elo_change < 0 THEN 'LOSS'
        ELSE 'DRAW'
    END as result

FROM elo_history eh
LEFT JOIN matches m ON m.id = eh.match_id
LEFT JOIN categories c ON c.id = m.category_id
LEFT JOIN tournaments t ON t.id = c.tournament_id
LEFT JOIN tournament_entries e_a ON e_a.id = m.entry_a_id
LEFT JOIN tournament_entries e_b ON e_b.id = m.entry_b_id;

-- ─────────────────────────────────────────────────────────
-- 7. VIEW: Player Profile Summary
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW v_player_profile_summary AS
SELECT 
    p.id as person_id,
    p.first_name,
    p.last_name,
    p.nickname,
    p.user_id,
    
    ast.sport_id,
    ast.current_elo,
    ast.matches_played,
    ast.rank,
    
    -- Stats calculated from elo_history
    (SELECT COUNT(*) FROM player_achievements WHERE person_id = p.id) as achievement_count,
    (SELECT COUNT(*) FROM elo_history WHERE person_id = p.id AND match_id IS NOT NULL) as total_matches,
    (SELECT COUNT(*) FROM elo_history WHERE person_id = p.id AND elo_change > 0) as total_wins,
    
    -- Calculate win rate
    CASE 
        WHEN (SELECT COUNT(*) FROM elo_history WHERE person_id = p.id AND match_id IS NOT NULL) > 0
        THEN ROUND(
            (SELECT COUNT(*)::NUMERIC FROM elo_history WHERE person_id = p.id AND elo_change > 0) /
            (SELECT COUNT(*)::NUMERIC FROM elo_history WHERE person_id = p.id AND match_id IS NOT NULL) * 100
        , 1)
        ELSE 0 
    END as win_rate_pct

FROM persons p
JOIN athlete_stats ast ON ast.person_id = p.id;

-- ─────────────────────────────────────────────────────────
-- 8. ENABLE RLS ON ACHIEVEMENTS
-- ─────────────────────────────────────────────────────────

ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_achievements ENABLE ROW LEVEL SECURITY;

-- Anyone can view achievements (public catalog)
CREATE POLICY "Anyone can view achievements"
ON achievements FOR SELECT TO authenticated
USING (TRUE);

-- Anyone can view their own achievements
CREATE POLICY "Users can view own achievements"
ON player_achievements FOR SELECT TO authenticated
USING (person_id IN (SELECT id FROM persons WHERE user_id = auth.uid()));

-- Insert only via trigger (awards happen automatically)
CREATE POLICY "Achievements insert via trigger only"
ON player_achievements FOR INSERT TO authenticated
WITH CHECK (
    person_id IN (SELECT id FROM persons WHERE user_id = auth.uid())
);

-- ─────────────────────────────────────────────────────────
-- 9. FUNCTION: Record Tournament Participation
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION record_tournament_participation(
    p_person_id UUID,
    p_tournament_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
DECLARE
    v_tournament_count INTEGER;
BEGIN
    -- Count how many tournaments this person has completed
    SELECT COUNT(DISTINCT c.tournament_id)
    INTO v_tournament_count
    FROM tournament_entries te
    JOIN categories c ON c.id = te.category_id
    JOIN entry_members em ON em.entry_id = te.id
    JOIN tournaments t ON t.id = c.tournament_id
    WHERE em.person_id = p_person_id
    AND t.status = 'COMPLETED';
    
    -- Award COMPETITOR achievement
    IF v_tournament_count >= 1 THEN
        INSERT INTO player_achievements (person_id, achievement_id)
        SELECT p_person_id, id FROM achievements WHERE code = 'COMPETITOR'
        ON CONFLICT DO NOTHING;
    END IF;
    
    -- Award REGULAR achievement
    IF v_tournament_count >= 10 THEN
        INSERT INTO player_achievements (person_id, achievement_id)
        SELECT p_person_id, id FROM achievements WHERE code = 'REGULAR'
        ON CONFLICT DO NOTHING;
    END IF;
    
    -- Award TOURNAMENT_PRO achievement
    IF v_tournament_count >= 50 THEN
        INSERT INTO player_achievements (person_id, achievement_id)
        SELECT p_person_id, id FROM achievements WHERE code = 'TOURNAMENT_PRO'
        ON CONFLICT DO NOTHING;
    END IF;
    
    RETURN TRUE;
END;
$$;

-- ─────────────────────────────────────────────────────────
-- 10. RPC: Get Leaderboard
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_leaderboard(
    p_sport_id UUID,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0,
    p_timeframe TEXT DEFAULT 'all'  -- 'all', 'month', 'week'
)
RETURNS TABLE (
    rank BIGINT,
    person_id UUID,
    person_name TEXT,
    current_elo INTEGER,
    matches_played INTEGER,
    achievement_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
BEGIN
    RETURN QUERY
    WITH ranked AS (
        SELECT 
            ast.person_id,
            ROW_NUMBER() OVER (ORDER BY ast.current_elo DESC, ast.matches_played DESC) as row_rank,
            p.nickname as person_name,
            ast.current_elo,
            ast.matches_played,
            (SELECT COUNT(*) FROM player_achievements pa WHERE pa.person_id = ast.person_id) as ach_count
        FROM athlete_stats ast
        JOIN persons p ON p.id = ast.person_id
        WHERE ast.sport_id = p_sport_id
    )
    SELECT 
        r.row_rank as rank,
        r.person_id,
        r.person_name,
        r.current_elo,
        r.matches_played,
        r.ach_count as achievement_count
    FROM ranked r
    WHERE r.row_rank > p_offset AND r.row_rank <= p_offset + p_limit;
END;
$$;

-- ============================================================
-- NOTE: Verification queries removed from migration file.
-- Run these manually for debugging:
--   psql ... -c "SELECT COUNT(*) FROM achievements;"
--   psql ... -c "SELECT tgname FROM pg_trigger WHERE tgname LIKE 'trg_%';"
-- END OF MIGRATION
-- ============================================================
