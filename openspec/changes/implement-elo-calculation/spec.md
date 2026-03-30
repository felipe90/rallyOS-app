# Delta: ELO Calculation Trigger

## ADDED Requirements

### Requirement: ELO Calculation Function

The system MUST implement the `process_match_completion()` function that calculates and applies ELO changes when a match finishes.

#### ELO Formula Specification

```
Expected Score = 1 / (1 + 10^((Rating Opponent - Rating Player) / 400))
K-Factor = 32 (players with < 30 matches), 24 (30-100 matches), 16 (> 100 matches)
New Rating = Old Rating + K * (Actual Score - Expected Score)
```

### Requirement: Trigger Execution

The system MUST attach a trigger to the `matches` table that fires when match status changes TO `FINISHED`.

| Scenario | Behavior |
|----------|----------|
| Status changes to FINISHED | Execute ELO calculation |
| Status changes from FINISHED | No action |
| Other status changes | No action |

### Requirement: ELO History Recording

The system MUST record ELO changes in `elo_history` table:

| Field | Value |
|-------|-------|
| person_id | Winner/Loser UUID |
| sport_id | Sport from category |
| match_id | The completed match |
| previous_elo | ELO before match |
| new_elo | ELO after match |
| elo_change | Positive for winner, negative for loser |
| change_type | 'MATCH_WIN' or 'MATCH_LOSS' |

### Requirement: Athlete Stats Update

The system MUST update `athlete_stats` after match completion:

| Field | Update |
|-------|--------|
| current_elo | Add/subtract elo_change |
| matches_played | Increment by 1 |

### Requirement: K-Factor Determination

The system MUST determine K-factor based on `matches_played` in `athlete_stats`:

| Matches Played | K-Factor |
|----------------|----------|
| 0-29 | 32 |
| 30-99 | 24 |
| 100+ | 16 |

---

## Scenarios

#### Scenario: Match completion triggers ELO calculation

- GIVEN a match exists with entry_a and entry_b
- AND both entries have person members
- AND both persons have athlete_stats records for the sport
- WHEN match status changes to 'FINISHED'
- THEN the process_match_completion trigger executes
- AND elo_history entries are created for both players
- AND athlete_stats are updated with new ELO values

#### Scenario: Winner gains ELO, loser loses ELO

- GIVEN winner has 1500 ELO, loser has 1400 ELO
- AND both have < 30 matches (K=32)
- WHEN match completes
- THEN expected score for winner = 1 / (1 + 10^((1400-1500)/400)) ≈ 0.573
- AND winner gains ≈ 32 * (1 - 0.573) = 13.66 ≈ 14 points
- AND loser loses 14 points
- AND elo_history shows winner +14, loser -14

#### Scenario: K-factor changes after threshold

- GIVEN a player has 29 matches (K=32)
- WHEN they complete another match (now 30)
- THEN their K-factor changes to 24 for next match
- AND subsequent matches use K=24

#### Scenario: New player starts at default ELO

- GIVEN a new player has no matches (default ELO 1000)
- WHEN they win against a 1200 ELO player
- THEN they gain significant ELO due to high K-factor (32)
- AND the expected score was low due to rating difference

---

## Migration

| File | Change |
|------|--------|
| `supabase/migrations/00000000000005_implement_elo_calculation.sql` | Create function and trigger |

## Implementation Notes

1. Use SECURITY DEFINER to bypass RLS for inserts to elo_history
2. Handle NULL athlete_stats gracefully (INSERT with default values)
3. Use POWER() for exponential calculation, not ^ (which is XOR in PostgreSQL)
4. ROUND() the ELO change to nearest integer

## Success Criteria

- [ ] Migration runs without errors
- [ ] Trigger fires on match FINISHED status
- [ ] elo_history entries created for both players
- [ ] athlete_stats.current_elo updated correctly
- [ ] athlete_stats.matches_played incremented
- [ ] K-factor varies correctly by match count
- [ ] ELO change calculated correctly per formula
