# RallyOS: Sequence Diagrams — Business Logic Flows

**Generated**: 2026-03-30

---

## 1. ELO Calculation on Match Completion

**Trigger**: `process_match_completion()`  
**When**: `matches.status` changes to `FINISHED`

```mermaid
sequenceDiagram
    autonumber
    participant Client as App/Referee
    participant DB as PostgreSQL
    participant RLS as RLS Engine
    participant Trigger as Trigger
    participant ELO as ELO Calculator
    participant Stats as athlete_stats

    Client->>RLS: UPDATE matches SET status = 'FINISHED'
    
    RLS->>RLS: Check: user in tournament_staff?
    RLS-->>Trigger: ✅ Allowed (ORGANIZER/EXTERNAL_REFEREE)
    
    Trigger->>Trigger: Read OLD.status (not FINISHED)
    Trigger->>Trigger: NEW.status = 'FINISHED'
    
    Trigger->>DB: SELECT entry_a_id, entry_b_id FROM matches
    DB-->>Trigger: entry_a_id, entry_b_id
    
    Trigger->>DB: SELECT sport_id FROM categories c<br/>JOIN matches m ON c.id = m.category_id
    DB-->>Trigger: sport_id
    
    Trigger->>Trigger: Determine winner from sets_json
    Note over Trigger: Count sets where a > b<br/>Winner = entry with more sets

    Trigger->>DB: SELECT current_elo, matches_played<br/>FROM athlete_stats<br/>WHERE person_id = winner
    DB-->>Trigger: winner_elo, winner_matches
    
    Trigger->>DB: SELECT current_elo, matches_played<br/>FROM athlete_stats<br/>WHERE person_id = loser
    DB-->>Trigger: loser_elo, loser_matches
    
    Trigger->>ELO: Calculate K-factor
    Note over ELO: if <30 matches: K=32<br/>if 30-100: K=24<br/>if >100: K=16
    
    Trigger->>ELO: Calculate expected score
    Note over ELO: Expected = 1/(1+10^((loser-winner)/400))
    
    Trigger->>ELO: Calculate elo_change
    Note over ELO: change = K*(1-Expected)
    
    Trigger->>Stats: INSERT INTO elo_history<br/>(winner, previous_elo, new_elo, +change, MATCH_WIN)
    Stats-->>Trigger: ✅ Inserted
    
    Trigger->>Stats: UPDATE athlete_stats<br/>SET current_elo = current_elo + change<br/>WHERE person_id = winner
    Stats-->>Trigger: ✅ Updated
    
    Trigger->>Stats: INSERT INTO elo_history<br/>(loser, previous_elo, new_elo, -change, MATCH_LOSS)
    Stats-->>Trigger: ✅ Inserted
    
    Trigger->>Stats: UPDATE athlete_stats<br/>SET current_elo = current_elo - change<br/>WHERE person_id = loser
    Stats-->>Trigger: ✅ Updated
    
    Trigger-->>Client: RETURN NEW
    Note over Client: ELO updated for both players
```

### Test Scenarios

| Scenario | Input | Expected |
|----------|-------|----------|
| Winner gains ELO | 1000 vs 800, winner wins | Winner +8, Loser -8 |
| Higher ELO wins | 1200 vs 1000, higher wins | Small change (< 10) |
| Upset! | 1200 vs 1000, lower wins | Big change (> 15) |
| First match | 0 matches played | K = 32 |
| Veteran | 150 matches played | K = 16 |

---

## 2. Bracket Advancement

**Trigger**: `advance_bracket_winner()`  
**When**: `matches.status` changes to `FINISHED`

```mermaid
sequenceDiagram
    autonumber
    participant Trigger as Trigger
    participant DB as PostgreSQL
    participant Final as Next Match

    Trigger->>Trigger: Match became FINISHED
    
    Trigger->>DB: SELECT sets_json FROM scores<br/>WHERE match_id = current_match_id
    DB-->>Trigger: sets_json
    
    Trigger->>Trigger: Count sets won by entry_a
    Note over Trigger: sets_a = count where a > b
    
    Trigger->>Trigger: Determine winner
    alt sets_a > (total_sets - sets_a)
        Note over Trigger: entry_a is winner
    else sets_a <= (total_sets - sets_a)
        Note over Trigger: entry_b is winner
    end
    
    Trigger->>DB: SELECT next_match_id<br/>FROM matches<br/>WHERE id = current_match_id
    DB-->>Trigger: next_match_id (e.g., final_id)
    
    alt next_match_id IS NOT NULL
        Trigger->>DB: SELECT entry_a_id, entry_b_id<br/>FROM matches<br/>WHERE id = next_match_id
        DB-->>Trigger: entry_a_id, entry_b_id
        
        alt entry_a_id IS NULL
            Trigger->>Final: UPDATE matches<br/>SET entry_a_id = winner_entry_id
            Note over Final: Winner placed in entry_a slot
        else entry_b_id IS NULL
            Trigger->>Final: UPDATE matches<br/>SET entry_b_id = winner_entry_id
            Note over Final: Winner placed in entry_b slot
        else Both filled
            Note over Trigger: This shouldn't happen<br/>Both slots already filled
        end
        
        Trigger->>DB: Re-check entry_a_id, entry_b_id
        
        alt Both entries present
            Trigger->>Final: UPDATE matches<br/>SET status = 'SCHEDULED'
            Note over Final: Final is ready to play!
        else Still waiting
            Note over Final: Waiting for other semifinal
        end
        
    else next_match_id IS NULL
        Note over Trigger: No next match<br/>This is the championship match
    end
```

### Test Scenarios

| Scenario | Input | Expected |
|----------|-------|----------|
| Semifinal winner to Final | Semi1 finished, winner advances | Final.entry_a_id = winner |
| Both semifinals done | Semi1 + Semi2 finished | Final has both entries, status = SCHEDULED |
| Entry_b wins | 2-3 sets (b wins more) | entry_b_id placed in next match |
| No next match | Final match finishes | No error, no advancement |

---

## 3. Entry Registration with Payment Flow

**Flow**: Registration → Payment → Confirmation

```mermaid
sequenceDiagram
    autonumber
    participant Player as App
    participant Supabase as Supabase
    participant RLS as RLS
    participant Entry as tournament_entries
    participant Payment as Payment
    participant Webhook as Stripe/MP Webhook

    Player->>Supabase: INSERT tournament_entries<br/>(category_id, person_id)
    
    Supabase->>RLS: Check INSERT policy
    RLS-->>Supabase: ✅ Allowed (authenticated)
    
    Supabase->>Entry: INSERT with status='PENDING_PAYMENT'
    Entry-->>Supabase: entry created
    Note over Player: Entry created<br/>Payment pending

    Supabase->>Player: Return entry with PENDING_PAYMENT

    Player->>Player: Open payment modal<br/>(Stripe/MercadoPago)
    
    Player->>Payment: Pay $25.00
    Payment->>Payment: Process payment
    Payment-->>Player: Payment success

    Payment->>Webhook: POST /webhook/payment<br/>{txn_id, status: SUCCEEDED}
    
    Webhook->>Supabase: UPDATE payments<br/>SET status = 'SUCCEEDED'
    
    Webhook->>Supabase: UPDATE tournament_entries<br/>SET status = 'CONFIRMED'
    Note over Webhook: Player can now participate
    
    Supabase-->>Webhook: ✅ Updated
    
    Webhook-->>Payment: ✅ Ack
```

### Test Scenarios

| Scenario | Input | Expected |
|----------|-------|----------|
| New entry starts pending | INSERT without status | status = PENDING_PAYMENT |
| Payment confirmed | Webhook calls UPDATE | status = CONFIRMED |
| Payment failed | Webhook calls UPDATE | status = CANCELLED |
| Non-owner can't confirm | Random user tries UPDATE | ❌ Blocked by RLS |
| Organizer can override | Organizer updates status | ✅ Allowed |

---

## 4. Tournament Creation with Auto-Organizer

**Trigger**: `assign_tournament_creator_as_organizer()`  
**When**: New tournament INSERT

```mermaid
sequenceDiagram
    autonumber
    participant Organizer as User/Organizer
    participant Supabase as Supabase
    participant RLS as RLS
    participant Trigger as Trigger
    participant Staff as tournament_staff

    Organizer->>Supabase: INSERT tournaments<br/>(name, sport_id)
    
    Supabase->>RLS: Check INSERT policy
    RLS-->>Supabase: ✅ Allowed (auth.uid() IS NOT NULL)
    
    Supabase->>Supabase: INSERT tournament record
    Supabase-->>Organizer: Return tournament
    
    Note over Supabase: AFTER INSERT fires
    
    Trigger->>Trigger: Get NEW.id (tournament)
    Trigger->>Trigger: Get auth.uid() (creator)
    
    Trigger->>Staff: INSERT INTO tournament_staff<br/>(tournament_id, user_id, 'ORGANIZER')
    Staff-->>Trigger: ✅ Inserted
    
    Note over Organizer: Creator is automatically<br/>assigned as ORGANIZER
```

---

## 5. Offline Sync Conflict Resolution

**Trigger**: `check_offline_sync_conflict()`  
**When**: UPDATE on matches/scores with `local_updated_at`

```mermaid
sequenceDiagram
    autonumber
    participant Client as Offline App
    participant DB as PostgreSQL
    participant Trigger as Trigger

    Client->>DB: UPDATE matches<br/>SET status = 'LIVE',<br/>local_updated_at = '2024-01-15T10:30:00Z'
    
    Trigger->>Trigger: Read NEW.local_updated_at
    Trigger->>Trigger: Read OLD.local_updated_at
    
    alt NEW.local_updated_at > NOW() + 5 min
        Note over Trigger: 🚨 TIME TAMPERING!<br/>Client trying to use future time
        Trigger-->>DB: RAISE EXCEPTION<br/>'Timestamp in the future is not allowed'
        DB-->>Client: ❌ Error: Time-Tampering protection
    end
    
    alt NEW.local_updated_at < OLD.local_updated_at
        Note over Trigger: ⚠️ OLD DATA!<br/>Client has stale data
        Trigger-->>DB: RETURN OLD
        Note over Client: Update silently ignored<br/>Server keeps current data
    end
    
    Trigger->>DB: Update proceeds
    DB-->>Client: ✅ Success (new data accepted)
```

### Test Scenarios

| Scenario | Input | Expected |
|----------|-------|----------|
| Valid update | local_updated_at = NOW() | ✅ Accepted |
| Future timestamp | local_updated_at = +1 day | ❌ Blocked |
| Past timestamp | local_updated_at = yesterday | Silently ignored |
| Same timestamp | local_updated_at = OLD | Accepted |

---

## 6. Match Score Update (RLS Check)

**RLS Policy**: Only assigned referee can update scores

```mermaid
sequenceDiagram
    autonumber
    participant Referee as Assigned Referee
    participant App as Any User
    participant RLS as RLS
    participant Scores as scores

    Referee->>RLS: UPDATE scores<br/>SET points_a = 5<br/>WHERE match_id = 'match-123'
    
    RLS->>RLS: Check policy<br/>"Scores insert/update allowed<br/>only for assigned referee"
    RLS->>RLS: Verify referee_id matches auth.uid()
    RLS-->>Scores: ✅ Allowed
    
    Scores->>Scores: UPDATE points_a = 5
    Scores-->>Referee: ✅ Updated

   ---

    App->>RLS: UPDATE scores<br/>SET points_a = 5<br/>WHERE match_id = 'match-123'
    
    RLS->>RLS: Check referee_id = auth.uid()
    RLS-->>RLS: ❌ auth.uid() != referee_id
    RLS-->>App: ❌ Error 403<br/>'new row violates row-level<br/>security policy'
    Note over App: Blocked!<br/>Only referee can update
```

---

## Summary of Business Logic

| Flow | Trigger/Function | Status |
|------|-----------------|--------|
| ELO Calculation | `process_match_completion()` | ✅ Implemented |
| Bracket Advancement | `advance_bracket_winner()` | ✅ Implemented |
| Payment Confirmation | Webhook (manual) | ⚠️ Table ready |
| Auto-Organizer | `assign_tournament_creator_as_organizer()` | ✅ Implemented |
| Offline Sync Protection | `check_offline_sync_conflict()` | ✅ Implemented |
| Score RLS | Policy | ✅ Implemented |
