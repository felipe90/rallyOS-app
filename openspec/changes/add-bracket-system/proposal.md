# Proposal: Add bracket_system to categories table

## Intent

Implement tournament bracket system support in the domain model. The `categories` table lacks a `bracket_system` field to distinguish between SINGLE_ELIMINATION, ROUND_ROBIN, and future formats (DOUBLE_ELIMINATION, SWISS). This enables organizers to configure how tournament brackets are generated and how losers are handled.

## Scope

### In Scope
- Create `bracket_system` PostgreSQL enum type with values: `SINGLE_ELIMINATION`, `ROUND_ROBIN`
- Add `bracket_system` column to `categories` table with default `SINGLE_ELIMINATION`
- Document the enum values and their behavior in the schema

### Out of Scope
- Double Elimination bracket logic (future enhancement)
- Swiss System implementation (future enhancement)
- UI changes for bracket configuration
- Bracket generation algorithm

## Approach

Create a new migration file `00000000000002_add_bracket_system.sql` that:

1. Creates the enum type:
   ```sql
   CREATE TYPE bracket_system AS ENUM ('SINGLE_ELIMINATION', 'ROUND_ROBIN');
   ```

2. Adds the column with default:
   ```sql
   ALTER TABLE categories ADD COLUMN bracket_system bracket_system DEFAULT 'SINGLE_ELIMINATION';
   ```

The enum follows existing patterns (e.g., `game_mode` enum) for consistency.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `supabase/migrations/00000000000002_add_bracket_system.sql` | New | Migration to add enum and column |
| `supabase/migrations/00000000000000_init_schema.sql` | Reference | Existing schema (categories table at lines 32-42) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Migration failure if column exists | Low | Use `IF NOT EXISTS` for enum; check column before ALTER |
| Breaking existing queries | Low | New column has default; existing code unaffected |
| Frontend expects column | Low | Document in spec; update frontend types |

## Rollback Plan

```sql
-- Rollback migration
ALTER TABLE categories DROP COLUMN IF EXISTS bracket_system;
DROP TYPE IF EXISTS bracket_system;
```

To undo: run the rollback SQL against the database.

## Dependencies

- Existing `categories` table in `00000000000000_init_schema.sql`
- No external dependencies

## Success Criteria

- [ ] Migration `00000000000002_add_bracket_system.sql` applies without errors
- [ ] `bracket_system` enum type exists with correct values
- [ ] `categories.bracket_system` column exists with `SINGLE_ELIMINATION` default
- [ ] Existing categories have `SINGLE_ELIMINATION` as default value
- [ ] Security tests pass: `psql ... -f supabase/tests/security_tests.sql`
