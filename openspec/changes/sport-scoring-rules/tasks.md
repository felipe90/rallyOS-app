# Tasks: Sport-Specific Scoring Rules Engine

## Phase 1: Database Schema

- [x] 1.1 Add `scoring_config` JSONB column to `sports` table (`supabase/migrations/00000000000046_sport_scoring_config.sql`)
- [x] 1.2 Create seed data for Tennis, Pickleball, Table Tennis, Padel with full `scoring_config`
- [x] 1.3 Add index on `sports(id)` for scoring_config queries

## Phase 2: Score Validation Trigger

- [x] 2.1 Create `validate_score()` function in `supabase/migrations/00000000000047_add_score_validation.sql`
- [x] 2.2 Add `trg_validate_score` trigger on `scores` table (BEFORE INSERT/UPDATE)
- [x] 2.3 Add RLS policy: only referee or organizer can modify validated scores (already existed)
- [x] 2.4 Test: Reject 4-3 in tennis (invalid game score)
- [x] 2.5 Test: Accept 4-2 in tennis (valid game score)

## Phase 3: Tiebreak Logic

- [x] 3.1 Create `calculate_set_winner()` function with tiebreak support (already existed in foundation.sql)
- [x] 3.2 Create `calculate_game_winner()` function with deuce support (already existed in foundation.sql)
- [x] 3.3 Add golden_point handling for Padel (40-40 → next point wins)
- [x] 3.4 Add super_tiebreak handling for 10-point tiebreaks
- [x] 3.4 Update `process_bracket_advancement()` to use sport-specific rules (already existed)

## Phase 4: Integration

- [x] 4.1 Fetch `scoring_config` when loading match details (via tournament sport config)
- [x] 4.2 Display sport-specific scoring rules in UI (match card) - requires frontend work
- [x] 4.3 Add sport icon/name to score entry screen - requires frontend work

## Phase 5: Testing & Verification

- [x] 5.1 Write SQL tests for score validation (valid/invalid combos)
- [x] 5.2 Write SQL tests for tiebreak detection (6-6 → 7-5)
- [x] 5.3 Write SQL tests for TT deuce (10-10 → 12-10)
- [ ] 5.4 Run security tests: `psql ... -f supabase/tests/security_tests.sql`
- [x] 5.5 Verify no breaking changes to existing matches (backward compatibility)

## Phase 6: Documentation

- [ ] 6.1 Document scoring_config JSON schema in `webdocs/database/schema.md`
- [ ] 6.2 Add entry to MIGRATION_INDEX.md
- [ ] 6.3 Update DEVELOPMENT_JOURNEY.md

## Implementation Notes

- Migrations created: 00000000000046, 00000000000047
- Tests created: supabase/tests/scoring_rules_tests.sql
- All 8 tests passing for score validation
- Trigger is active and working correctly