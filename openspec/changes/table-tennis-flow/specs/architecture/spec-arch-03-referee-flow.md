# SPEC-ARCH-03: Architecture - Referee Flow

## Purpose

Definir la arquitectura del frontend para el flujo de arbitraje intra-grupo y la regla "el perdedor arbitra".

---

## Referee Assignment Flow

### During Round Robin Phase

```
┌─────────────────────────────────────────────────────────────┐
│                    MATCH REFS                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  MATCH: P1 vs P2 (Group A)                                 │
│  Round 2 of 6                                               │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                                                     │   │
│  │  Suggested Referee: P3 ⭐                          │   │
│  │  Reason: "Loser of previous match has priority"    │   │
│  │                                                     │   │
│  │  [Confirm]  [Choose Another]                       │   │
│  │                                                     │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Available from Group A:                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ ⭐ P3 - Has BYE this round              [Select]   │   │
│  │   P4 - 0 matches refereed               [Select]   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### After Match Completion

```
┌─────────────────────────────────────────────────────────────┐
│                 MATCH COMPLETED                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  RESULT: P1 defeated P2 (11-8, 8-11, 11-5)                 │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                                                     │   │
│  │  P2 (loser) will referee P1's next match           │   │
│  │  ⭐ Automatically assigned                          │   │
│  │                                                     │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Next Match: P1 vs P3                                       │
│  Referee: P2 (loser of this match)                        │
│                                                             │
│  [Enter Score]  [Continue]                                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## API Endpoints

### GET /matches/:id/referee-suggestion

Get suggested referee for a match.

```typescript
interface RefereeSuggestionResponse {
  match_id: string;
  suggestion: {
    user_id: string;
    person: Person;
    assignment_type: 'AUTOMATIC' | 'MANUAL' | 'LOSER_ASSIGNED';
    reason: string;
    confidence: number; // 0-1
  } | null;
  available_referees: Array<{
    user_id: string;
    person: Person;
    matches_refereed: number;
    is_available: boolean;
    reason_unavailable?: string;
  }>;
}
```

### POST /matches/:id/referee

Assign referee to a match.

```typescript
interface AssignRefereeRequest {
  user_id: string;
  assignment_type: 'MANUAL' | 'LOSER_ASSIGNED';
  is_organizer_override?: boolean;
}

interface AssignRefereeResponse {
  assignment: RefereeAssignment;
  next_match_loser_assigned?: {
    match_id: string;
    user_id: string;
    message: string;
  };
}
```

### POST /matches/:id/confirm-referee

Organizer confirms referee suggestion.

```typescript
interface ConfirmRefereeRequest {
  match_id: string;
}
```

### DELETE /matches/:id/referee

Remove referee from match.

```typescript
interface ClearRefereeResponse {
  success: boolean;
  message: string;
}
```

---

## Loser-as-Referee Logic

### Automatic Assignment Flow

```typescript
interface LoserRefereeService {
  /**
   * Called when a match finishes
   * Assigns loser to winner's next match
   */
  onMatchComplete(matchId: string): Promise<{
    assigned: boolean;
    refereeId?: string;
    reason?: string;
    crossGroupConflict?: boolean;
  }>;
  
  /**
   * Check if loser can referee next match
   */
  canLoserReferee(
    loserUserId: string,
    nextMatchId: string
  ): Promise<{
    canReferee: boolean;
    reason?: string;
  }>;
}
```

### Decision Tree

```
Match Completed (P1 beats P2)
         │
         ▼
┌─────────────────────┐
│ Get P1's next match │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│ Is there a next     │──No──▶ [Final Match - No assignment]
│ match?              │
└─────────┬───────────┘
          │Yes
          ▼
┌─────────────────────┐
│ Is P2 in same group │──No──▶ [Cross-group - Manual assignment]
│ as next match?      │
└─────────┬───────────┘
          │Yes
          ▼
┌─────────────────────┐
│ Does P2 have        │──No──▶ [Assign P2 as referee]
│ user_id?            │
└─────────┬───────────┘
          │Yes (shadow)
          ▼
┌─────────────────────┐
│ Find next available │───▶ [Manual assignment]
│ from same group     │
└─────────────────────┘
```

---

## UI Components

### MatchRefereeCard Component

```typescript
interface MatchRefereeCardProps {
  match: Match;
  suggestion: RefereeSuggestion | null;
  availableReferees: Person[];
  onConfirm: (userId: string) => void;
  onChange: (userId: string) => void;
  isOrganizer: boolean;
  isEditable: boolean;
}
```

### RefereeAvailabilityBadge

```typescript
interface RefereeAvailabilityBadgeProps {
  person: Person;
  isAvailable: boolean;
  reason?: string;
  matchesRefereed: number;
}

// Visual states:
// 🟢 Available (referee icon, green)
// 🟡 BYE This Round (star icon, yellow)
// 🔴 Unavailable - Playing (X icon, red)
// ⚫ Unavailable - No User (shadow icon, gray)
```

### LoserAssignmentToast

```typescript
interface LoserAssignmentToastProps {
  loser: Person;
  winner: Person;
  nextMatch: Match;
  onDismiss: () => void;
}

// Shown after match completion
// "P2 will referee P1's next match vs P3"
```

---

## State Management

### useRefereeStore

```typescript
interface RefereeState {
  // Current match being set up
  currentMatch: Match | null;
  suggestion: RefereeSuggestion | null;
  availableReferees: Person[];
  
  // Pending assignments
  pendingAssignments: Map<string, RefereeAssignment>;
  
  // Actions
  fetchSuggestion: (matchId: string) => Promise<void>;
  assignReferee: (matchId: string, userId: string) => Promise<void>;
  confirmSuggestion: (matchId: string) => Promise<void>;
  clearReferee: (matchId: string) => Promise<void>;
  
  // Loser flow
  handleMatchComplete: (matchId: string) => Promise<LoserAssignment>;
}
```

---

## Special Cases

### 1. No Available Referees

```
┌─────────────────────────────────────────────────────────────┐
│  MATCH: P1 vs P2 (Group A)                                 │
│                                                             │
│  ⚠️ No Available Referees                                  │
│                                                             │
│  Everyone is either:                                       │
│  • Playing in this match                                   │
│  • Has already refereed twice                              │
│                                                             │
│  Options:                                                  │
│  • [Request Organizer to Referee]                         │
│  • [Skip Referee - Self-Judge]                             │
│  • [Wait for Player to Finish Other Match]                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2. Cross-Group Next Match

```
┌─────────────────────────────────────────────────────────────┐
│  CROSS-GROUP DETECTED                                      │
│                                                             │
│  P2 (loser) is from Group A                                │
│  P1's next match is in Group B                             │
│                                                             │
│  P2 cannot referee a match from Group B                    │
│                                                             │
│  Please choose a referee manually:                         │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ From Group B:                                       │  │
│  │ [B1] [B3] [B4] (B2 is playing)                    │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 3. Final Match (No Next Match)

```
┌─────────────────────────────────────────────────────────────┐
│  FINAL: P1 vs P2                                           │
│                                                             │
│  This is the final match.                                  │
│  No referee will be auto-assigned.                        │
│                                                             │
│  Please designate a referee:                               │
│  • [Loser of Bronze Match]                                 │
│  • [Organizer]                                             │
│  • [Choose from Available]: [dropdown]                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Offline Handling

### Pending Referee Assignments

```typescript
interface PendingRefereeAssignment {
  match_id: string;
  user_id: string;
  assignment_type: string;
  timestamp: number;
  synced: boolean;
}

// Stored in local state, synced when online
const pendingAssignments = createPersistAtom('pending_referee_assignments', {
  default: [],
  storage: AsyncStorage,
});
```

### Sync on Reconnect

```typescript
// When coming back online
const syncRefereeAssignments = async () => {
  const pending = get(pendingAssignments);
  
  for (const assignment of pending) {
    try {
      await api.assignReferee(assignment.match_id, {
        user_id: assignment.user_id,
        assignment_type: assignment.assignment_type,
        offline_created: true,
      });
      // Remove from pending
      removePending(assignment.match_id);
    } catch (error) {
      // Keep in pending, retry later
    }
  }
};
```
