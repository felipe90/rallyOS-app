# SPEC-ARCH-01: Architecture - Tournament State Machine

## Purpose

Definir la arquitectura del frontend y API para manejar los estados del torneo TT en RallyOS.

---

## Tournament State Machine

```
┌─────────┐    ┌──────────────┐    ┌────────────────┐    ┌──────────┐    ┌──────┐    ┌───────────┐
│  DRAFT  │───▶│ REGISTRATION │───▶│ PRE_TOURNAMENT │───▶│ CHECK_IN │───▶│ LIVE │───▶│ COMPLETED │
└─────────┘    └──────────────┘    └────────────────┘    └──────────┘    └──────┘    └───────────┘
     │                │                     │                   │            │
     │                │                     │                   │            ▼
     │                │                     │                   │       ┌───────────┐
     │                │                     │                   │       │ SUSPENDED │
     │                │                     │                   │       └───────────┘
     │                │                     │                   │
     │                │                     │                   ▼
     │                │                     │            ┌───────────┐
     │                │                     │            │ CANCELLED │
     │                │                     │            └───────────┘
     └────────────────┴─────────────────────┴─────────────────────────────┘
                              (Back to DRAFT - edit mode)
```

---

## API Endpoints

### GET /tournaments/:id

Returns tournament with current state and relevant data.

```typescript
interface TournamentResponse {
  id: string;
  name: string;
  sport_id: string;
  status: TournamentStatus;
  created_at: string;
  
  // Based on status
  entries_count?: number;
  groups_count?: number;
  groups?: RoundRobinGroup[];
  bracket?: KnockoutBracket;
  
  // User context
  user_role?: 'organizer' | 'staff' | 'player' | 'none';
  user_entry_id?: string;
  check_in_status?: 'not_checked_in' | 'checked_in';
}
```

### PATCH /tournaments/:id/status

Transition tournament to next state (organizer only).

```typescript
interface StatusTransitionRequest {
  new_status: TournamentStatus;
}

// Valid transitions:
// DRAFT → REGISTRATION
// REGISTRATION → PRE_TOURNAMENT (requires ≥3 entries)
// PRE_TOURNAMENT → CHECK_IN
// CHECK_IN → LIVE
// LIVE → COMPLETED
// ANY → SUSPENDED (emergency)
// ANY → CANCELLED
```

### Response Codes

| Transition | Success | Error |
|------------|---------|-------|
| DRAFT → REGISTRATION | 200 | 400: Invalid transition |
| REGISTRATION → PRE_TOURNAMENT | 200 | 400: Not enough entries |
| PRE_TOURNAMENT → CHECK_IN | 200 | 400: Groups not ready |
| CHECK_IN → LIVE | 200 | 400: < 2 checked in |
| LIVE → COMPLETED | 200 | 400: Matches pending |

---

## Frontend State Management

### Zustand Store: `useTournamentStore`

```typescript
interface TournamentState {
  // Current tournament
  tournament: Tournament | null;
  loading: boolean;
  error: string | null;
  
  // Computed
  canCreateGroups: boolean;
  canStartTournament: boolean;
  currentPhase: 'registration' | 'groups' | 'knockout' | 'finished';
  
  // Actions
  fetchTournament: (id: string) => Promise<void>;
  transitionStatus: (newStatus: TournamentStatus) => Promise<void>;
  refreshFromServer: () => Promise<void>;
}
```

### Computed Properties

```typescript
// Derived from tournament.status and related data
const computeTournamentPhase = (tournament: Tournament) => {
  switch (tournament.status) {
    case 'DRAFT':
    case 'REGISTRATION':
      return 'registration';
    case 'PRE_TOURNAMENT':
    case 'CHECK_IN':
      return tournament.groups.length > 0 ? 'groups' : 'registration';
    case 'LIVE':
      return tournament.bracket ? 'knockout' : 'groups';
    case 'COMPLETED':
      return 'finished';
    default:
      return 'registration';
  }
};
```

---

## UI Components by Status

### DRAFT / REGISTRATION Phase

```
┌─────────────────────────────────────────┐
│  Tournament: TT Amateur Championship   │
│  Status: 📝 Registration Open          │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Registered Players (12/20)     │   │
│  │  ┌─────┐ ┌─────┐ ┌─────┐       │   │
│  │  │ P1  │ │ P2  │ │ P3  │ ...    │   │
│  │  └─────┘ └─────┘ └─────┘       │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [Edit Tournament]  [Start Check-In]   │
└─────────────────────────────────────────┘
```

### PRE_TOURNAMENT Phase (Group Creation)

```
┌─────────────────────────────────────────┐
│  Tournament: TT Amateur Championship   │
│  Status: ⚙️ Setting Up Groups          │
│                                         │
│  Groups (not yet started)              │
│  ┌─────────────┐  ┌─────────────┐      │
│  │ Group A     │  │ Group B     │      │
│  │ Head: P1 ⭐ │  │ Head: P5 ⭐ │      │
│  │ Members: 4  │  │ Members: 4  │      │
│  │ Matches: 6  │  │ Matches: 6  │      │
│  └─────────────┘  └─────────────┘      │
│                                         │
│  [+ Add Group]  [Generate Bracket]      │
└─────────────────────────────────────────┘
```

### CHECK_IN Phase

```
┌─────────────────────────────────────────┐
│  Tournament: TT Amateur Championship   │
│  Status: ✅ Check-In Open              │
│                                         │
│  Check-In (8/12 players)              │
│  ┌─────────────────────────────────┐    │
│  │ ✓ P1 (checked in)              │    │
│  │ ✓ P2 (checked in)              │    │
│  │ ○ P3 (not checked in)          │    │
│  │ ✓ P4 (checked in)              │    │
│  │ ...                            │    │
│  └─────────────────────────────────┘    │
│                                         │
│  [Start Tournament]  [Adjust Groups]   │
└─────────────────────────────────────────┘
```

### LIVE Phase (Groups)

```
┌─────────────────────────────────────────┐
│  Tournament: TT Amateur Championship   │
│  Status: 🔴 LIVE - Round Robin        │
│                                         │
│  Group A - Match 3 of 6               │
│  ┌─────────────────────────────────┐    │
│  │  CURRENT: P1 vs P2             │    │
│  │  Referee: P3                    │    │
│  │  Court: Table 1                 │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Standings:                           │
│  1. P1 - 6 pts (2-0)                  │
│  2. P3 - 3 pts (1-0)                  │
│  3. P2 - 0 pts (0-1)                  │
│  4. P4 - 0 pts (0-1)                  │
│                                         │
│  [Enter Score]  [View All Groups]      │
└─────────────────────────────────────────┘
```

### LIVE Phase (Knockout)

```
┌─────────────────────────────────────────┐
│  Tournament: TT Amateur Championship   │
│  Status: 🔴 LIVE - Knockout           │
│                                         │
│  Quarterfinals - Match 2 of 4         │
│  ┌─────────────────────────────────┐    │
│  │  A1 (1st Grp A) vs B2 (2nd Grp B)│   │
│  │  Referee: A2 (lost to A1)       │   │
│  └─────────────────────────────────┘    │
│                                         │
│  Bracket:                              │
│  QF1: A1 vs B2  → Winner vs ???       │
│  QF2: C1 vs D2  → Winner vs ???       │
│  ...                                   │
│                                         │
│  [Enter Score]  [View Full Bracket]     │
└─────────────────────────────────────────┘
```

---

## Navigation Flow

```
Registration → Pre-Tournament → Check-In → Live (Groups) → Live (KO) → Completed
     │               │               │            │            │
     │               ▼               ▼            ▼            ▼
     │          [Create]      [Check-In]  [Enter Score] [Enter Score]
     │          [Edit]        [Adjust]   [Referee]    [Referee]
     │          [Seed]                      [Standings]  [Bracket]
     │          [Groups]                                  
```

---

## Error Handling

### Invalid Status Transitions

```typescript
const STATUS_TRANSITIONS: Record<TournamentStatus, TournamentStatus[]> = {
  'DRAFT': ['REGISTRATION'],
  'REGISTRATION': ['PRE_TOURNAMENT', 'CANCELLED'],
  'PRE_TOURNAMENT': ['CHECK_IN', 'CANCELLED'],
  'CHECK_IN': ['LIVE', 'CANCELLED'],
  'LIVE': ['COMPLETED', 'SUSPENDED', 'CANCELLED'],
  'SUSPENDED': ['LIVE', 'CANCELLED'],
  'COMPLETED': [],
  'CANCELLED': []
};

// Usage
const canTransition = (from: TournamentStatus, to: TournamentStatus): boolean => {
  return STATUS_TRANSITIONS[from].includes(to);
};
```

### Validation Errors

| Error | User Message | Action |
|-------|--------------|--------|
| Not enough entries | "Need at least 3 players to create groups" | Stay on page |
| Groups incomplete | "All groups must have 3-5 members" | Show validation |
| Check-in insufficient | "Need at least 2 players checked in" | Block start |
| Matches pending | "Complete all group matches first" | Show pending |
