# Delta for Tournament Scoring Rules

## ADDED Requirements

### Requirement: Sport-Specific Scoring Configuration

The system MUST store sport-specific scoring rules in a JSONB column `scoring_config` in the `sports` table.

The `scoring_config` JSONB MUST contain:
- `points_to_win_game`: Integer (e.g., 4 for tennis, 11 for pickleball/TT)
- `points_to_win_tiebreak`: Integer (e.g., 7)
- `win_by_two_points`: Boolean (true for all three sports)
- `win_by_two_games`: Boolean (true for tennis, false for pickleball/TT)
- `games_to_win_set`: Integer (6 for tennis)
- `tiebreak_at`: Integer (6 for tennis at 6-6)
- `has_tiebreak`: Boolean
- `has_super_tiebreak`: Boolean
- `super_tiebreak_points`: Integer (10 for super tiebreak)
- `scoring_type`: Enum ('standard', 'tennis_15_30_40', 'rally')

#### Scenario: Seed data includes all 4 sports

- GIVEN empty `sports` table
- WHEN seed runs
- THEN Tennis, Pickleball, Table Tennis, Padel exist with correct scoring_config

### Requirement: Score Entry Validation

The system MUST validate score entries against sport-specific rules via trigger.

The trigger `validate_match_score()` MUST:
- Reject scores where game score >= `points_to_win_game` but not winning by 2 (unless tiebreak)
- Reject set scores that violate `win_by_two_games` rule
- Reject match completion if final set is incomplete

#### Scenario: Invalid tennis game score

- GIVEN match with Tennis scoring (points_to_win_game = 4)
- WHEN score entry attempts player_a_game_score = 4, player_b_game_score = 3
- THEN entry is REJECTED (not win by 2)

#### Scenario: Valid tennis game score

- GIVEN match with Tennis scoring
- WHEN score entry attempts player_a_game_score = 4, player_b_game_score = 2
- THEN entry is ACCEPTED

### Requirement: Tiebreak Logic

The system MUST calculate tiebreak winners correctly when `has_tiebreak = true`.

The function `calculate_set_winner()` MUST:
- Detect when game score reaches `tiebreak_at` (typically 6-6)
- Apply tiebreak scoring (7 points, win by 2)
- Handle super tiebreak (10 points, win by 2) when `has_super_tiebreak = true`

#### Scenario: Tennis tiebreak at 6-6

- GIVEN tennis match at set_score = (6, 6)
- WHEN tiebreak scores entered as (7, 5)
- THEN set winner is player A, match continues

### Requirement: Table Tennis Deuce Handling

The system MUST handle Table Tennis "deuce" at 10-10 correctly.

The scoring logic MUST:
- Recognize 10-10 as deuce state
- Require 2-point lead to win game
- Continue until 12-10, 13-11, etc.

#### Scenario: TT game at 10-10

- GIVEN table tennis match at game_score = (10, 10)
- WHEN score entered as (12, 10)
- THEN game winner is player A

### Requirement: Pickleball Rally Scoring

The system MUST support Pickleball rally scoring mode.

The config MUST:
- Set `scoring_type = 'rally'`
- Set `points_to_win_game = 11`
- Set `win_by_two_points = true`

#### Scenario: Pickleball rally score entry

- GIVEN pickleball match with rally scoring
- WHEN score entered as (11, 9)
- THEN game winner is player A, set advances

### Requirement: Padel Scoring (Golden Point)

The system MUST support Padel's golden point scoring at deuce.

The config MUST:
- Set `scoring_type = 'tennis_15_30_40'`
- Set `points_to_win_game = 4`
- Set `win_by_two_games = true`
- Set `has_golden_point = true` (at 40-40, next point wins)
- Set `has_tiebreak = true` (at 6-6)

#### Scenario: Padel golden point at deuce

- GIVEN padel match at game_score = (40, 40)
- WHEN score entered as (ADV, 40) or (40, ADV)
- THEN game winner is the player who scored the golden point

## MODIFIED Requirements

### Requirement: Bracket Advancement with Sport Rules

(Previously: Bracket advancement used hardcoded generic rules)

The system MUST apply sport-specific rules when determining match winners and advancing bracket.

- GIVEN match is FINISHED with valid scores
- WHEN `process_bracket_advancement()` is called
- THEN sport-specific rules from `sports.scoring_config` determine winner

## REMOVED Requirements

(None - this is a new feature)

## Security Considerations

| Requirement | Description |
|-------------|-------------|
| Score Validation RLS | Only match referee or organizer can modify validated scores |
| Audit Trail | All score changes logged to `elo_history` with reason |
