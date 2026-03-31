# Design: SPEC-005 - Person CRUD con RLS

## Technical Approach

Enable Row Level Security on `persons` table to secure player profile management. Follow existing RLS patterns from `scores` and `matches` policies.

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|----------|
| SELECT policy | `auth.role() = 'authenticated'` | All authenticated users need to view persons for tournament registration |
| INSERT policy | `auth.uid() = user_id OR user_id IS NULL` | Users create own profiles; organizers create guest profiles with NULL |
| UPDATE policy | `auth.uid() = user_id` | Users update only their own profiles |
| DELETE policy | `auth.uid() = user_id` | Users delete only their own profiles |

## Data Flow

```
Client (auth.uid = X)
    │
    ├─→ INSERT persons (user_id = X) ──→ ✅ Allowed
    ├─→ INSERT persons (user_id = NULL) ──→ ✅ Allowed (organizer)
    ├─→ UPDATE persons WHERE user_id = X ──→ ✅ Allowed
    ├─→ UPDATE persons WHERE user_id ≠ X ──→ ❌ Denied by RLS
    └─→ SELECT persons ──→ ✅ All returned (no filter)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `supabase/migrations/00000000000007_add_persons_rls.sql` | Create | RLS policies for persons |

## SQL Implementation

```sql
-- Enable RLS
ALTER TABLE persons ENABLE ROW LEVEL SECURITY;

-- SELECT: Anyone authenticated can view all persons
-- Needed for tournament registration (organizer needs to see players)
CREATE POLICY "Persons are readable by authenticated users"
ON persons FOR SELECT
USING (auth.role() = 'authenticated');

-- INSERT: Users create own OR organizers create guests (NULL user_id)
CREATE POLICY "Users can create own person or guest"
ON persons FOR INSERT
WITH CHECK (
    auth.uid() = user_id
    OR user_id IS NULL
);

-- UPDATE: Users update only their own profile
CREATE POLICY "Users can update own person"
ON persons FOR UPDATE
USING (auth.uid() = user_id);

-- DELETE: Users delete only their own profile
CREATE POLICY "Users can delete own person"
ON persons FOR DELETE
USING (auth.uid() = user_id);
```

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| SQL | RLS policies | Manual `psql` tests with different auth.uid() |
| Integration | App flow | Test from mobile app with authenticated user |

## Migration

No data migration required. Existing `persons` records will be accessible per new policies.

## Open Questions

None.
