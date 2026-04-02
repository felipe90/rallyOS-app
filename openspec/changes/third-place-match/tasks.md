# Tasks: Third Place Match (On-Demand)

## Phase 1: Schema (Foundation)

- [ ] 1.1 Add `third_place_pending` BOOLEAN DEFAULT FALSE to matches table
- [ ] 1.2 Add `third_place_accepted` BOOLEAN NULL to matches table
- [ ] 1.3 Add RLS policies for the new columns (organizer can update, players can read)

## Phase 2: RPCs (Core Implementation)

- [ ] 2.1 Create `offer_third_place(p_match_id UUID)` function
  - Sets third_place_pending = TRUE
  - Validates match is FINISHED semi-final
- [ ] 2.2 Create `accept_third_place(p_match_id UUID, p_accepted BOOLEAN)` function
  - Sets third_place_accepted = p_accepted
  - Validates caller is player in match
- [ ] 2.3 Create `get_match_loser(p_match_id UUID)` function
  - Returns loser entry_id from scores
- [ ] 2.4 Create `create_third_place_match(p_semi_a UUID, p_semi_b UUID)` function
  - Gets losers from both semis
  - Creates new match with round_name = 'Third Place'
  - Validates both accepted = TRUE

## Phase 3: Testing

- [ ] 3.1 Test: offer_third_place sets pending flag
- [ ] 3.2 Test: accept_third_place records acceptance
- [ ] 3.3 Test: create_third_place_match creates match with correct losers
- [ ] 3.4 Test: get_match_loser returns correct loser

## Phase 4: Integration

- [ ] 4.1 Update advance_bracket_winner to detect both semis finished with acceptances
- [ ] 4.2 Add third place match to MIGRATION_INDEX.md
- [ ] 4.3 Run security tests

## Phase 5: Documentation

- [ ] 5.1 Update schema.md with new columns
- [ ] 5.2 Update ER_DIAGRAM.md
- [ ] 5.3 Update DEVELOPMENT_JOURNEY.md
