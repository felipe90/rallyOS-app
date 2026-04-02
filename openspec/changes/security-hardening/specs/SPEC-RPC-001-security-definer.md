# SPEC-SEC-RPC-001: SECURITY DEFINER on All RPCs

## Purpose

Add `SECURITY DEFINER` to all critical RPCs that need to bypass RLS for internal operations or be called from other functions.

## Background

Current state audit revealed all 11 critical RPCs lack `SECURITY DEFINER`:
- They use `auth.uid()` directly
- This works when PostgREST calls them with JWT
- This FAILS when called from triggers or other SECURITY DEFINER functions
- This creates a security anti-pattern

## Why SECURITY DEFINER?

PostgreSQL has two security contexts:
1. **INVOKER** (default): Uses caller's privileges
2. **DEFINER**: Uses function owner's privileges

For RPCs that need to:
- Read/write data bypassing RLS for internal operations
- Be called from triggers or other functions
- Perform system-level operations

SECURITY DEFINER is required.

## Requirements

### Requirement: RPC Classification

All RPCs must be classified into two categories:

**Category A: External-Facing (Keep INVOKER)**
RPCs called directly by PostgREST with JWT:
- `accept_invitation` - Called by authenticated user
- `reject_invitation` - Called by authenticated user
- `toggle_referee_volunteer` - Called by authenticated user

**Category B: Internal/Trigger-Facing (NEED SECURITY DEFINER)**
RPCs called from triggers or need system-level access:
- `create_round_robin_group` - Called by organizer, needs to create records
- `generate_round_robin_matches` - Called by trigger, needs DB writes
- `offer_third_place` - Called by organizer
- `accept_third_place` - Called by user
- `create_third_place_match` - Called by organizer
- `get_match_loser` - Helper function, pure read
- `assign_staff` - Needs to write to tournament_staff
- `invite_staff` - Needs to write to tournament_staff
- `generate_referee_suggestions` - Needs to write to referee_assignments
- `validate_score` - Called by trigger, needs to validate

### Requirement: SECURITY DEFINER Pattern

Each RPC needs:
```sql
CREATE OR REPLACE FUNCTION function_name(...)
RETURNS ...
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public  -- Prevent search_path attacks
AS $$
BEGIN
    -- Authorization check first
    IF NOT authorized THEN
        RAISE EXCEPTION 'Access denied';
    END IF;
    
    -- Business logic
    ...
END;
$$;
```

**CRITICAL**: Even with SECURITY DEFINER, always check authorization explicitly. SECURITY DEFINER bypasses RLS but NOT application-level auth.

### Requirement: Authorization Checks

Each RPC must have explicit authorization:

```sql
-- For organizer-only RPCs:
IF NOT EXISTS (
    SELECT 1 FROM tournament_staff
    WHERE tournament_id = p_tournament_id
    AND user_id = auth.uid()
    AND role = 'ORGANIZER'
    AND status = 'ACTIVE'
) THEN
    RAISE EXCEPTION 'Access denied: Only ORGANIZER can call this function';
END IF;
```

## RPC Specifications

### 1. create_round_robin_group

```sql
CREATE OR REPLACE FUNCTION create_round_robin_group(
    p_tournament_id UUID,
    p_name TEXT,
    p_member_entry_ids UUID[],
    p_advancement_count INTEGER DEFAULT 2
)
RETURNS TABLE(group_id UUID, match_ids UUID[])
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
DECLARE
    v_group_id UUID;
    v_match_ids UUID[] := '{}';
BEGIN
    -- Authorization
    IF NOT EXISTS (
        SELECT 1 FROM tournament_staff
        WHERE tournament_id = p_tournament_id
        AND user_id = auth.uid()
        AND role = 'ORGANIZER'
        AND status = 'ACTIVE'
    ) THEN
        RAISE EXCEPTION 'Access denied: Only ORGANIZER can create groups';
    END IF;
    
    -- Business logic...
END;
$$;
```

### 2. generate_round_robin_matches

```sql
CREATE OR REPLACE FUNCTION generate_round_robin_matches(p_group_id UUID)
RETURNS UUID[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
-- No auth check - called internally by create_round_robin_group
-- which already checked authorization
```

### 3. offer_third_place

```sql
CREATE OR REPLACE FUNCTION offer_third_place(p_match_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
-- Checks: caller is organizer of tournament
```

### 4. accept_third_place

```sql
CREATE OR REPLACE FUNCTION accept_third_place(p_match_id UUID, p_accepted BOOLEAN)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
-- Checks: caller is player in the match
```

### 5. create_third_place_match

```sql
CREATE OR REPLACE FUNCTION create_third_place_match(p_semi_a UUID, p_semi_b UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
-- Checks: caller is organizer, both semis accepted
```

### 6. get_match_loser

```sql
CREATE OR REPLACE FUNCTION get_match_loser(p_match_id UUID)
RETURNS UUID
LANGUAGE plpgsql
STABLE  -- Read-only function
SET search_path TO extensions, public
AS $$
-- Pure read, no auth needed
```

### 7. assign_staff

```sql
CREATE OR REPLACE FUNCTION assign_staff(
    p_tournament_id UUID,
    p_user_id UUID,
    p_role TEXT,
    p_direct BOOLEAN DEFAULT FALSE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
-- Checks: caller is organizer
```

### 8. invite_staff

```sql
CREATE OR REPLACE FUNCTION invite_staff(
    p_tournament_id UUID,
    p_user_id UUID,
    p_role TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
-- Checks: caller is organizer
```

### 9. generate_referee_suggestions

```sql
CREATE OR REPLACE FUNCTION generate_referee_suggestions(p_category_id UUID)
RETURNS TABLE(match_id UUID, user_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
-- Checks: caller is organizer or system
```

### 10. validate_score

```sql
CREATE OR REPLACE FUNCTION validate_score(
    p_match_id UUID,
    p_set_number INTEGER,
    p_points_a INTEGER,
    p_points_b INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SET search_path TO extensions, public
AS $$
-- Pure validation function, no auth needed
-- Reads from sports.scoring_config
```

## Migration

File: `supabase/migrations/00000000000049_rpc_security_definer.sql`

```sql
-- Drop and recreate each RPC with SECURITY DEFINER
-- Pattern for each function:

-- Example: create_round_robin_group
CREATE OR REPLACE FUNCTION create_round_robin_group(...)
RETURNS ...
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO extensions, public
AS $$
-- Full function body with auth check
$$;
```

## Verification

```sql
-- Verify SECURITY DEFINER
SELECT proname, prosrc LIKE '%SECURITY DEFINER%' as is_definer
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
AND proname IN (
    'create_round_robin_group', 'generate_round_robin_matches',
    'offer_third_place', 'accept_third_place', 'create_third_place_match',
    'get_match_loser', 'assign_staff', 'invite_staff',
    'generate_referee_suggestions', 'validate_score'
)
ORDER BY proname;
```

## Expected Outcome

All 10 internal RPCs have `SECURITY DEFINER` with:
- Explicit `SET search_path TO extensions, public`
- Authorization checks at function start
- Proper error messages

## Security Notes

> **WARNING**: SECURITY DEFINER functions run with elevated privileges.
> - ALWAYS validate authorization explicitly
> - NEVER trust input without validation
> - Use SET search_path to prevent SQL injection via search_path
