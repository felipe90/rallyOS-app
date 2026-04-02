# Tasks: Third Place Match (On-Demand)

## Phase 1: Schema (Foundation)

- [x] 1.1 Add `third_place_pending` BOOLEAN DEFAULT FALSE to matches table
- [x] 1.2 Add `third_place_accepted` BOOLEAN NULL to matches table
- [x] 1.3 Add RLS policies for the new columns (organizer can update, players can read)

## Phase 2: RPCs (Core Implementation)

- [x] 2.1 Create `offer_third_place(p_match_id UUID)` function
  - Sets third_place_pending = TRUE
  - Validates match is FINISHED semi-final
- [x] 2.2 Create `accept_third_place(p_match_id UUID, p_accepted BOOLEAN)` function
  - Sets third_place_accepted = p_accepted
  - Validates caller is player in match
- [x] 2.3 Create `get_match_loser(p_match_id UUID)` function
  - Returns loser entry_id from scores
- [x] 2.4 Create `create_third_place_match(p_semi_a UUID, p_semi_b UUID)` function
  - Gets losers from both semis
  - Creates new match with round_name = 'Third Place'
  - Validates both accepted = TRUE

## Phase 3: Testing

- [x] 3.1 Test: offer_third_place sets pending flag
- [x] 3.2 Test: accept_third_place records acceptance
- [x] 3.3 Test: create_third_place_match creates match with correct losers
- [x] 3.4 Test: get_match_loser returns correct loser

## Phase 4: Integration

- [x] 4.1 Update advance_bracket_winner to detect both semis finished with acceptances
- [x] 4.2 Add third place match to MIGRATION_INDEX.md
- [x] 4.3 Run security tests

## Phase 5: Documentation

- [x] 5.1 Update schema.md with new columns
- [x] 5.2 Update ER_DIAGRAM.md
- [x] 5.3 Update DEVELOPMENT_JOURNEY.md
