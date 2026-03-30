# Proposal: Implement ELO Calculation Trigger

## Intent

Implement the `process_match_completion` trigger function that calculates ELO rating changes when a match finishes. This is the core ELO system that tracks athlete performance across matches.

## Scope

### In Scope
- Create `process_match_completion()` trigger function in PostgreSQL
- Attach trigger to `matches` table for `FINISHED` status transitions
- Implement standard ELO formula with K-factor based on match count
- Record ELO history entries for both winner and loser
- Update `athlete_stats` with new ELO and match count

### Out of Scope
- ELO decay/inactivity handling
- Tournament final bonuses
- Manual ELO adjustments (admin tools)

## Approach

1. **Create migration file** at `supabase/migrations/00000000000005_implement_elo_calculation.sql`

2. **Implement ELO formula**:
   ```
   Expected Score = 1 / (1 + 10^((Rating Opponent - Rating Player) / 400))
   K-Factor = 32 (for players with < 30 matches), 24 (30-100 matches), 16 (> 100 matches)
   New Rating = Old Rating + K * (Actual Score - Expected Score)
   ```

3. **Trigger logic**:
   - Trigger fires on `matches` table when status changes TO `FINISHED`
   - Get entry IDs and sport from match/category
   - Determine winner (simplified: entry_a wins)
   - Calculate ELO change using formula
   - Insert history records for both players
   - Update athlete_stats

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `supabase/migrations/00000000000005_implement_elo_calculation.sql` | Created | Migration with trigger function |
| `elo_history` table | Used | Records ELO changes |
| `athlete_stats` table | Modified | Updates ELO ratings |
| `matches` table | Trigger added | Fires on status change |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Missing athlete_stats for new player | Medium | Pre-create stats on registration |
| Division by zero | Low | Default ELO of 1000 handled |
| Null entries cause trigger failure | Medium | Add COALESCE defaults |

## Rollback Plan

Drop the trigger and function:
```sql
DROP TRIGGER IF EXISTS trg_match_completion ON matches;
DROP FUNCTION IF EXISTS process_match_completion();
```

## Success Criteria

- [ ] Migration runs without errors
- [ ] Trigger created on matches table
- [ ] Match completion creates elo_history entries
- [ ] athlete_stats updated with new ELO
- [ ] K-factor varies by match count
