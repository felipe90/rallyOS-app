# RallyOS: Architecture Diagrams

**Generated**: 2026-03-30  
**Related**: `docs/ARCHITECTURE.md` (strategy), `docs/MIGRATION_INDEX.md` (migrations)

---

## System Flow

```mermaid
graph TD
    subgraph Tournament_Creation
        A[User creates Tournament] --> B[Tournament INSERT]
        B --> C[Trigger: Assign Organizer]
        C --> D[tournament_staff INSERT]
    end

    subgraph Registration
        E[Player registers] --> F[tournament_entries INSERT]
        F --> G{Payment required?}
        G -->|Yes| H[status: PENDING_PAYMENT]
        G -->|No| I[status: CONFIRMED]
        H --> J[Webhook: Payment confirmed]
        J --> I
    end

    subgraph Match_Flow
        K[Referee starts Match] --> L[matches.status = 'READY']
        L --> M[matches.status = 'LIVE']
        M --> N[Scores updated]
        N --> N1{PIN Correct?}
        N1 -->|Yes| O{match ends?}
        N1 -->|No| N
        O -->|No| N
        O -->|Yes| P[matches.status = 'FINISHED']
    end

    subgraph ELO_Calculation
        P --> Q[Trigger: process_match_completion]
        Q --> Q1[Query match_sets for winner]
        Q1 --> Q2[Calculate ELO (Expected vs Actual)]
        Q2 --> Q3[elo_history INSERT]
        Q2 --> Q4[athlete_stats UPDATE]
    end

    subgraph Bracket_Advancement
        P --> R[Trigger: advance_bracket_winner]
        R --> R1[Get winner based on match_sets]
        R1 --> R2{next_match_id exists?}
        R2 -->|Yes| R2a[Read winner_to_slot]
        R2a --> R3[Place winner in specific Slot A or B]
        R2 -->|No| R4[Championship complete]
        R3 --> R5{Both slots filled?}
        R5 -->|Yes| R6[status: SCHEDULED]
        R5 -->|No| R7[Waiting for opponent]
    end

    style ELO_Calculation fill:#e1f5fe
    style Bracket_Advancement fill:#fff3e0
```

## Database Schema

```mermaid
erDiagram
    COUNTRIES ||--o{ PERSONS : "nationality"
    COUNTRIES ||--o{ CLUBS : "location"
    COUNTRIES ||--o{ TOURNAMENTS : "location"

    SPORTS ||--o{ ATHLETE_STATS : "has"
    SPORTS ||--o{ TOURNAMENTS : "defines"
    SPORTS ||--o{ ELO_HISTORY : "tracks"
    SPORTS ||--o{ ACHIEVEMENTS : "can have"
    
    TOURNAMENTS ||--o{ CATEGORIES : "contains"
    TOURNAMENTS ||--o{ TOURNAMENT_STAFF : "has"
    TOURNAMENTS ||--o{ COMMUNITY_FEED : "generates"
    
    CATEGORIES ||--o{ TOURNAMENT_ENTRIES : "registers"
    CATEGORIES ||--o{ MATCHES : "organizes"
    
    PERSONS ||--o{ ATHLETE_STATS : "has"
    PERSONS ||--o{ ENTRY_MEMBERS : "belongs to"
    PERSONS ||--o{ TOURNAMENT_STAFF : "works as"
    PERSONS ||--o{ PAYMENTS : "pays"
    PERSONS ||--o{ PLAYER_ACHIEVEMENTS : "earns"
    
    ATHLETE_STATS }o--|| SPORTS : "for sport"
    
    ACHIEVEMENTS ||--o{ PLAYER_ACHIEVEMENTS : "rewarded in"

    TOURNAMENT_ENTRIES ||--o{ ENTRY_MEMBERS : "composed of"
    TOURNAMENT_ENTRIES ||--o{ PAYMENTS : "has"
    
    MATCHES ||--|| SCORES : "has summary"
    MATCHES ||--o{ MATCH_SETS : "tracked in"
    MATCHES ||--o{ MATCHES : "advances via winner_to_slot"
    
    SCORES ||--o{ MATCH_SETS : "detailed by"
    
    ELO_HISTORY }o--|| PERSONS : "records for"
    ELO_HISTORY }o--|| MATCHES : "from match"
```

## Match Completion Flow

```mermaid
sequenceDiagram
    participant Client
    participant RLS
    participant Trigger
    participant elo_history
    participant athlete_stats
    participant bracket

    Client->>RLS: UPDATE matches SET status = 'FINISHED'
    RLS->>Trigger: Allow (staff role)
    
    Trigger->>Trigger: Query match_sets
    
    Note over Trigger: Determine winner by sets won
    
    Trigger->>elo_history: INSERT winner ELO
    Trigger->>athlete_stats: UPDATE winner stats
    
    Trigger->>elo_history: INSERT loser ELO
    Trigger->>athlete_stats: UPDATE loser stats
    
    Trigger->>bracket: SELECT next_match_id
    bracket-->>Trigger: next_match_id = "final-id"
    
    Trigger->>bracket: UPDATE entry_a_id = winner
    bracket->>bracket: Check if entry_b_id filled
    
    Note over bracket: Both entries present<br/>→ status = 'SCHEDULED'
    
    Trigger-->>Client: RETURN NEW
```

## RLS Security Model

```mermaid
flowchart TB
    subgraph Client
        A[Client App]
    end

    A --> B

    subgraph RLS
        C{Scores?<br/>referee_id?}
        D{Scores?<br/>staff?}
        E{Matches?<br/>staff?}
        F{Entries?<br/>owner/org?}
    end

    B --> C
    B --> D
    B --> E
    B --> F

    C -->|Yes| G[Write scores]
    D -->|Yes| H[Write matches]
    E -->|Yes| H
    F -->|Yes| I[Write entries]

    G --> J[elo_history<br/>SECURITY DEFINER]
    H --> J
    I --> I

    style J fill:#ffcdd2
```

## Bracket Structure (Single Elimination)

```
┌─────────────────────────────────────────────────────────────┐
│                    TOURNAMENT BRACKET                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   Semifinal 1              ┌─────────────────────┐         │
│  ┌─────────────────┐       │                     │         │
│  │ Felipe Wolf     │───────┤► Final              │         │
│  │ vs              │       │  ┌─────────────────┐│         │
│  │ Carlos Perez    │       │  │ Winner Semi 1   ││         │
│  └─────────────────┘       │  │ vs              ││         │
│         │                   │  │ Winner Semi 2   ││         │
│  [Winner advances]          │  └─────────────────┘│         │
│         │                   │         │           │         │
│   Semifinal 2              │   [Champion!]        │         │
│  ┌─────────────────┐       │         │           │         │
│  │ Andres Rojas    │───────┤►         ▼           │         │
│  │ vs              │       │    ┌─────────┐      │         │
│  │ Miguel Torres   │       │    │ Trophy  │      │         │
│  └─────────────────┘       │    └─────────┘      │         │
│                             └─────────────────────┘         │
│                                                             │
└─────────────────────────────────────────────────────────────┘

NEXT_MATCH_ID links:
  Semifinal 1.next_match_id → Final
  Semifinal 2.next_match_id → Final
```

## Key Triggers Reference

```yaml
trg_update_athlete_rank:        athlete_stats, BEFORE UPDATE, Rank Up (Bronze-Diamond)
trg_generate_match_pin:         matches, BEFORE INSERT, Identity security
trg_match_completion:           matches, AFTER UPDATE, REAL ELO Logic
trg_advance_bracket:            matches, AFTER UPDATE, Deterministic Advancement
trg_tournament_created_assign_organizer: tournaments, AFTER INSERT, Creator auth
trg_scores_conflict_resolution: scores, BEFORE UPDATE, Offline sync protection
```

## ELO Calculation Formula

```
Expected Score = 1 / (1 + 10^((Opponent Rating - Player Rating) / 400))

New Rating = Old Rating + K × (Actual Score - Expected Score)

Where:
- Actual Score = 1 (win), 0.5 (draw), 0 (loss)
- K-factor = 32 (< 30 matches), 24 (30-100), 16 (> 100)
```
