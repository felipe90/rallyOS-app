# Tasks: Implement ELO Calculation Trigger

## Phase 1: Implementation

- [x] 1.1 Create migration file `supabase/migrations/00000000000005_implement_elo_calculation.sql`
- [x] 1.2 Implement `process_match_completion()` function with ELO formula
- [x] 1.3 Attach trigger to matches table

## Phase 2: Verification

- [x] 2.1 Run `supabase db reset` to apply migration
- [x] 2.2 Create test match and finish it
- [x] 2.3 Verify elo_history entries created
- [x] 2.4 Verify athlete_stats updated with new ELO
- [x] 2.5 Test K-factor changes at thresholds (30, 100 matches)
