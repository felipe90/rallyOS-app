# SPEC-GAMIFICATION: Ranks & Achievements

## Purpose

Increase player retention and engagement by adding a layer of progression and public recognition (social status) within the platform.

## Data Model Changes

- **[NEW] `ranks` ENUM**: `(BRONZE, SILVER, GOLD, PLATINUM, DIAMOND)`
- **[NEW] `achievements` table**: Master list of available medallas.
- **[NEW] `player_achievements` table**: Links players to their earned awards with a timestamp.
- **`athlete_stats.rank`**: Denormalized current rank for fast UI rendering.

## Requirements

### Requirement: ELO-Based Ranks

The system MUST automatically assign a rank based on the player's current ELO.

| Rank | ELO Range |
| :--- | :--- |
| **BRONZE** | 0 - 1000 |
| **SILVER** | 1001 - 1200 |
| **GOLD** | 1201 - 1400 |
| **PLATINUM** | 1401 - 1600 |
| **DIAMOND** | 1601+ |

#### Scenario: Ranking Up
- GIVEN a Silver player with 1195 ELO
- WHEN they win a match and gain +10 ELO (New ELO: 1205)
- THEN their rank is updated to GOLD.

### Requirement: Automated Achievements

The system MUST trigger achievement awards based on match results and ELO changes.

#### Achievement: "First Blood"
- **Trigger**: First `match_win` recorded in `elo_history`.
- **Award**: "First Victory" medal.

#### Achievement: "Invictus" (Winning Streak)
- **Trigger**: 5 consecutive matches in `elo_history` with `change_type = 'MATCH_WIN'`.
- **Award**: "Winning Streak" badge.

#### Achievement: "Giant Killer" (Upset)
- **Trigger**: Winning a match where `Opponent Rating - Player Rating >= 200`.
- **Award**: "Giant Killer" medal.

## UI/UX Integration

- **Profile Badge**: The current rank MUST be displayed next to the player's name in all views.
- **Shareable Cards**: Achievements SHOULD be exportable as shareable graphics for WhatsApp/Instagram.
