# Delta for Third Place Match

## ADDED Requirements

### Requirement: Third Place Flags

The system MUST track third place match status via flags in the `matches` table.

The table `matches` MUST contain:
- `third_place_pending`: Boolean, default FALSE — indica si se ofreció third place
- `third_place_accepted`: Boolean, nullable — TRUE = aceptado, FALSE = rechazado, NULL = sin respuesta

#### Scenario: Add columns to matches table

- GIVEN matches table without third place columns
- WHEN migration 36 runs
- THEN columns exist with correct defaults

---

### Requirement: Offer Third Place

The system MUST allow the organizer to offer third place to players after a semi-final match ends.

The RPC `offer_third_place(p_match_id UUID)` MUST:
- Set `third_place_pending = TRUE` on the match
- Only allow if match status is FINISHED
- Only allow if round_name contains 'Semi-Final'
- Return success or raise exception

#### Scenario: Organizer offers third place

- GIVEN Semi-Final match is FINISHED
- WHEN organizer calls `offer_third_place(match_id)`
- THEN match has `third_place_pending = TRUE`
- AND response indicates success

---

### Requirement: Accept/Reject Third Place

The system MUST allow players (perdedores de semis) to accept or reject playing third place.

The RPC `accept_third_place(p_match_id UUID, p_accepted BOOLEAN)` MUST:
- Set `third_place_accepted = p_accepted` on the match
- Only allow if `third_place_pending = TRUE`
- Only allow if the caller is one of the players in the match
- Return success or raise exception

#### Scenario: Player accepts third place

- GIVEN match has `third_place_pending = TRUE`
- WHEN player calls `accept_third_place(match_id, TRUE)`
- THEN match has `third_place_accepted = TRUE`

#### Scenario: Player rejects third place

- GIVEN match has `third_place_pending = TRUE`
- WHEN player calls `accept_third_place(match_id, FALSE)`
- THEN match has `third_place_accepted = FALSE`

---

### Requirement: Create Third Place Match

The system MUST create a third place match when both semifinal losers accept.

The RPC `create_third_place_match(p_semi_a UUID, p_semi_b UUID)` MUST:
- Get loser from semi A (entry that lost)
- Get loser from semi B (entry that lost)
- Create new match with:
  - `round_name = 'Third Place'`
  - `entry_a_id = loser_a`
  - `entry_b_id = loser_b`
  - `status = SCHEDULED`
- Only allow if both semis have `third_place_accepted = TRUE`
- Only allow if called by organizer

#### Scenario: Both players accept, third place created

- GIVEN Semi A has `third_place_accepted = TRUE`, winner = P1, loser = P2
- GIVEN Semi B has `third_place_accepted = TRUE`, winner = P3, loser = P4
- WHEN organizer calls `create_third_place_match(semi_a, semi_b)`
- THEN new match exists with P2 vs P4
- AND round_name = 'Third Place'

---

### Requirement: Query Losers from Semis

The system MUST provide a way to get the loser entries from a semi-final match for creating third place.

The function `get_match_loser(p_match_id UUID)` MUST:
- Return the entry_id of the player who lost
- Use scores to determine winner/loser
- Return NULL if match not finished or no scores

#### Scenario: Get loser from finished match

- GIVEN match has scores (4-2), entry_a won, entry_b lost
- WHEN `get_match_loser(match_id)` is called
- THEN returns entry_b_id

---

## MODIFIED Requirements

### Requirement: Bracket Advancement with Third Place

(Previously: advance_bracket_winner only handled winners advancing to next_match_id)

The system SHOULD detect when both semis are finished and third place was accepted, and trigger the creation flow.

- GIVEN both semi-finals are FINISHED
- WHEN `advance_bracket_winner()` runs on either semi
- THEN check if both have `third_place_accepted = TRUE`
- AND emit notification or set flag for UI to prompt organizer

(Note: The actual creation is done via RPC, not automatic, to keep human in the loop)

---

## Security Considerations

| Requirement | Description |
|-------------|-------------|
| offer_third_place | Only organizer can call |
| accept_third_place | Only players in the match can call |
| create_third_place_match | Only organizer can call |
