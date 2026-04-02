# SPEC-ARCH-04: Architecture - Manual Score Entry

## Purpose

Definir la arquitectura del frontend para la entrada manual de scores en TT (scores escritos en papel, luego digitalizados).

---

## Score Entry Flow

### 1. Score Entry Screen

```
┌─────────────────────────────────────────────────────────────┐
│  ENTER SCORE                                        [X]     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Match: P1 vs P2                                            │
│  Group A - Round 2                                          │
│  Referee: P3                                                │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                                                     │   │
│  │              P1            P2                      │   │
│  │                                                     │   │
│  │  Set 1    [ 11 ]          [  8 ]   ✓ Valid          │   │
│  │  Set 2    [  8 ]          [ 11 ]   ✓ Valid          │   │
│  │  Set 3    [ 11 ]          [  5 ]   ✓ Valid          │   │
│  │  Set 4    [ __ ]          [ __ ]                    │   │
│  │  Set 5    [ __ ]          [ __ ]                    │   │
│  │                                                     │   │
│  │  ─────────────────────────────────────────────     │   │
│  │  Winner: P1 (3 sets to 1)                          │   │
│  │                                                     │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Set 3 of 5 - P1 serving                                   │
│                                                             │
│  [Cancel]                              [Submit Score]       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2. Score Validation Feedback

```
┌─────────────────────────────────────────────────────────────┐
│  SET 4                                                      │
│                                                             │
│              P1            P2                               │
│         [  10 ]        [  11 ]                              │
│                                                             │
│  ⚠️ Invalid Score                                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Must win by 2 points in Table Tennis                │   │
│  │                                                     │   │
│  │ Valid options:                                     │   │
│  │ • 12-10 (P2 wins by 2)                            │   │
│  │ • 11-9 (P1 wins by 2)                             │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 3. Deuce Scenario

```
┌─────────────────────────────────────────────────────────────┐
│  SET 3 - DEUCE                                             │
│                                                             │
│              P1            P2                               │
│         [  10 ]        [  10 ]     ⚡ Deuce!               │
│                                                             │
│  Score must reach 12 with 2-point difference               │
│                                                             │
│              P1            P2                               │
│         [  12 ]        [  10 ]                              │
│                                                             │
│  ✓ Valid - P1 wins set 3                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## API Endpoints

### POST /matches/:id/scores

Enter or update score for a match.

```typescript
interface EnterScoreRequest {
  points_a: number;
  points_b: number;
  set_number: number;
  entry_method: 'MANUAL'; // Always manual for TT
  recorded_by: string; // organizer or referee user_id
  paper_verified?: boolean; // Organizer verified from paper
}

interface EnterScoreResponse {
  score: Score;
  is_valid: boolean;
  validation_errors: string[];
  is_set_complete: boolean;
  is_match_complete: boolean;
  winner?: 'A' | 'B';
  next_action?: 'NEXT_SET' | 'MATCH_COMPLETE';
}
```

### POST /matches/:id/scores/batch

Batch enter multiple scores (for offline sync).

```typescript
interface BatchScoreRequest {
  scores: Array<{
    match_id: string;
    points_a: number;
    points_b: number;
    set_number: number;
    recorded_at: string; // When it was actually played
    recorded_by: string;
  }>;
}

interface BatchScoreResponse {
  results: Array<{
    match_id: string;
    success: boolean;
    error?: string;
  }>;
  matches_completed: number;
  points_awarded: Record<string, number>; // entry_id -> points
}
```

### GET /matches/:id/scores/history

Get full score history for audit.

```typescript
interface ScoreHistoryResponse {
  match_id: string;
  sets: Array<{
    set_number: number;
    points_a: number;
    points_b: number;
    winner: 'A' | 'B' | null;
    recorded_at: string;
    recorded_by: string;
  }>;
  current_set: number;
  sets_to_win: number;
}
```

---

## Validation Rules (Client-Side)

```typescript
interface TTValidationRules {
  pointsToWin: 11;
  winBy2: true;
  deuceAt: 10;
  superTiebreak: false;
}

const validateScore = (
  pointsA: number,
  pointsB: number,
  rules: TTValidationRules
): ValidationResult => {
  const maxPoints = Math.max(pointsA, pointsB);
  const diff = Math.abs(pointsA - pointsB);
  
  // Allow 0-0 as starting state
  if (pointsA === 0 && pointsB === 0) {
    return { valid: true };
  }
  
  // Before deuce (both < 11)
  if (maxPoints <= rules.deuceAt) {
    if (diff !== 1) {
      return { 
        valid: false, 
        error: 'Before 10-10, difference must be 1 point' 
      };
    }
    return { valid: true };
  }
  
  // At deuce or beyond (both >= 10)
  if (pointsA >= rules.deuceAt && pointsB >= rules.deuceAt) {
    if (diff !== 2) {
      return { 
        valid: false, 
        error: 'In deuce, must win by 2 points' 
      };
    }
    return { valid: true };
  }
  
  // One reaches 11 (other < 10)
  if (maxPoints === 11 && diff >= 2) {
    return { valid: true };
  }
  
  // Extended (12+, must be by 2)
  if (maxPoints >= 12 && diff === 2) {
    return { valid: true };
  }
  
  return { 
    valid: false, 
    error: `Invalid score ${pointsA}-${pointsB}. Must win by 2.` 
  };
};
```

---

## UI Components

### ScoreEntryCard

```typescript
interface ScoreEntryCardProps {
  match: Match;
  currentSet: number;
  setsToWin: number;
  onSubmit: (score: ScoreInput) => void;
  onCancel: () => void;
  isOffline: boolean;
  pendingSync?: boolean;
}
```

### SetScoreInput

```typescript
interface SetScoreInputProps {
  playerA: Person;
  playerB: Person;
  setNumber: number;
  initialScoreA?: number;
  initialScoreB?: number;
  onValidChange: (valid: boolean) => void;
  onScoreChange: (a: number, b: number) => void;
  disabled: boolean;
}
```

### ValidationBadge

```typescript
interface ValidationBadgeProps {
  pointsA: number;
  pointsB: number;
  rules: TTValidationRules;
}

// States:
// ✓ Valid (green check)
// ⚠️ Warning (yellow) - e.g., unusual but valid
// ✗ Invalid (red X) with explanation
```

### ScoreConfirmationModal

```typescript
interface ScoreConfirmationModalProps {
  match: Match;
  sets: CompletedSet[];
  finalScore: { a: number; b: number };
  winner: Person;
  onConfirm: () => void;
  onEdit: () => void;
  onCancel: () => void;
}
```

---

## State Management

### useScoreEntryStore

```typescript
interface ScoreEntryState {
  // Current entry session
  activeMatchId: string | null;
  currentSet: number;
  enteredScores: Map<number, { a: number; b: number }>;
  
  // Offline queue
  pendingScores: ScoreEntry[];
  
  // Actions
  startEntry: (matchId: string) => void;
  enterSetScore: (set: number, a: number, b: number) => void;
  validateCurrentScore: () => ValidationResult;
  submitScore: () => Promise<SubmitResult>;
  submitBatch: (scores: ScoreEntry[]) => Promise<BatchResult>;
  
  // Offline
  queueScore: (score: ScoreEntry) => void;
  syncPendingScores: () => Promise<SyncResult>;
}
```

---

## Offline Handling

### Score Queue

```typescript
interface OfflineScoreEntry {
  id: string; // UUID
  match_id: string;
  set_number: number;
  points_a: number;
  points_b: number;
  recorded_at: string; // Actual time of match
  recorded_by: string;
  synced: boolean;
  created_at: number; // When entered in app
}

// Persisted to local storage
const offlineScores = createPersistAtom('offline_score_entries', {
  default: [],
  storage: AsyncStorage,
});
```

### Sync Strategy

```typescript
// When coming back online
const syncScores = async () => {
  const pending = offlineScores.filter(s => !s.synced);
  
  // Sort by recorded_at to maintain order
  pending.sort((a, b) => 
    new Date(a.recorded_at).getTime() - new Date(b.recorded_at).getTime()
  );
  
  // Batch sync
  if (pending.length > 1) {
    const result = await api.submitBatch({ scores: pending });
    
    // Mark synced
    for (const entry of result.results) {
      if (entry.success) {
        markSynced(entry.match_id);
      }
    }
  } else if (pending.length === 1) {
    await api.enterScore(pending[0].match_id, pending[0]);
  }
};
```

---

## Paper Score Integration

### Organizer Verification Flow

```
1. Referee writes score on paper during match
2. After match, organizer reviews paper scores
3. Organizer enters scores in app
4. System validates each score
5. If valid, organizer marks as "paper_verified: true"
6. Score is committed
```

### Offline Paper Score Mode

```
┌─────────────────────────────────────────────────────────────┐
│  OFFLINE MODE - Paper Score Entry                          │
│                                                             │
│  Matches played offline:                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ ✓ P1 vs P2 - 11-8, 8-11, 11-5    [Enter in App]    │   │
│  │ ✓ P3 vs P4 - 11-9, 11-7          [Enter in App]    │   │
│  │ ○ P5 vs P6 - Pending paper                     ... │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ⚠️ 2 matches waiting to sync                             │
│  [Sync Now] (waiting for connection)                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Error Handling

| Error | User Message | Resolution |
|-------|--------------|------------|
| Invalid score format | "Score must be numbers 0-99" | Re-enter |
| Not win by 2 | "Must win by 2 points in TT" | Show valid options |
| Match already complete | "This match is already finished" | Refresh data |
| Unauthorized | "Only referee or organizer can enter scores" | Re-login |
| Network error | "Score saved, will sync when online" | Queue locally |

---

## Audit Trail

Every score entry is tracked:

```typescript
interface ScoreAuditEntry {
  id: string;
  match_id: string;
  set_number: number;
  points_a: number;
  points_b: number;
  recorded_at: string;
  recorded_by: string;
  entry_method: 'MANUAL' | 'ONLINE';
  paper_verified: boolean;
  offline_sync: boolean;
  synced_at?: string;
  modified_at?: string;
  modified_by?: string;
}
```
