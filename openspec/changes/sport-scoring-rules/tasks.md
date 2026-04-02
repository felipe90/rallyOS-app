# Tasks: Sport-Specific Scoring Rules Engine

## Phase 1: Database Schema

- [ ] 1.1 Add `scoring_config` JSONB column to `sports` table (`supabase/migrations/0000000000000X_add_sport_scoring_config.sql`)
- [ ] 1.2 Create seed data for Tennis, Pickleball, Table Tennis, Padel with full `scoring_config`
- [ ] 1.3 Add index on `sports(id)` for scoring_config queries

## Phase 2: Score Validation Trigger

- [ ] 2.1 Create `validate_score()` function in `supabase/migrations/0000000000000X_add_score_validation.sql`
- [ ] 2.2 Add `trg_validate_score` trigger on `scores` table (BEFORE INSERT/UPDATE)
- [ ] 2.3 Add RLS policy: only referee or organizer can modify validated scores
- [ ] 2.4 Test: Reject 4-3 in tennis (invalid game score)
- [ ] 2.5 Test: Accept 4-2 in tennis (valid game score)

## Phase 3: Tiebreak Logic

- [ ] 3.1 Create `calculate_set_winner()` function with tiebreak support
- [ ] 3.2 Create `calculate_game_winner()` function with deuce support
- [ ] 3.3 Add golden_point handling for Padel (40-40 → next point wins)
- [ ] 3.4 Add super_tiebreak handling for 10-point tiebreaks
- [ ] 3.4 Update `process_bracket_advancement()` to use sport-specific rules

## Phase 4: Integration

- [ ] 4.1 Fetch `scoring_config` when loading match details
- [ ] 4.2 Display sport-specific scoring rules in UI (match card)
- [ ] 4.3 Add sport icon/name to score entry screen

## Phase 5: Testing & Verification

- [ ] 5.1 Write SQL tests for score validation (valid/invalid combos)
- [ ] 5.2 Write SQL tests for tiebreak detection (6-6 → 7-5)
- [ ] 5.3 Write SQL tests for TT deuce (10-10 → 12-10)
- [ ] 5.4 Run security tests: `psql ... -f supabase/tests/security_tests.sql`
- [ ] 5.5 Verify no breaking changes to existing matches (backward compatibility)

## Phase 6: Documentation

- [ ] 6.1 Document scoring_config JSON schema in `webdocs/database/schema.md`
- [ ] 6.2 Add entry to MIGRATION_INDEX.md
- [ ] 6.3 Update DEVELOPMENT_JOURNEY.md
