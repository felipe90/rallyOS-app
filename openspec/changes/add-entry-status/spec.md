# Delta for Database: Tournament Entry Status

## Purpose

Adds a state machine to `tournament_entries` to track payment lifecycle from registration through confirmation. This enables bracket generation to only include entries with `CONFIRMED` status, and captures the fee amount at registration time for audit and dispute resolution.

---

## ADDED Requirements

### Requirement: Entry Status State Machine

The system SHALL maintain exactly one of three mutually exclusive statuses for every tournament entry: `PENDING_PAYMENT`, `CONFIRMED`, or `CANCELLED`.

### Requirement: Default Status on Registration

When a new tournament entry is created without an explicit status, the system SHALL assign `PENDING_PAYMENT` as the default status.

### Requirement: Fee Snapshot at Registration

The system SHALL capture and persist the tournament fee amount (in cents) at the time of entry registration in the `fee_amount_snap` column.

### Requirement: RLS Policy for Status Updates

The system SHALL enforce that only the entry owner or a user with `ORGANIZER` role for the tournament MAY update the `status` column.

### Requirement: RLS Policy for Status Visibility

The system SHALL allow all authenticated users to SELECT entries, including their status, for tournament browsing.

---

## ADDED Scenarios

### Scenario: New entry starts as PENDING_PAYMENT

- GIVEN a user creates a new tournament entry without specifying status
- WHEN the INSERT operation is executed
- THEN the entry status SHALL be `PENDING_PAYMENT` by default

### Scenario: Entry confirmed after successful payment

- GIVEN an entry exists with status `PENDING_PAYMENT`
- WHEN the payment webhook confirms successful payment
- THEN the entry status SHALL change to `CONFIRMED`
- AND the `fee_amount_snap` SHALL be set to the amount captured at registration

### Scenario: Entry cancelled after failed payment

- GIVEN an entry exists with status `PENDING_PAYMENT`
- WHEN the payment webhook reports payment failure
- THEN the entry status SHALL change to `CANCELLED`

### Scenario: Organizer can manually confirm entry

- GIVEN a user who is an ORGANIZER for the tournament (but NOT the entry owner)
- WHEN they update an entry's status to `CONFIRMED`
- THEN the update SHALL succeed
- AND the `fee_amount_snap` SHALL be set

### Scenario: Seed data reflects existing confirmed entries

- GIVEN all seed entries have corresponding `SUCCEEDED` payment records
- WHEN seed data is loaded via `supabase db reset`
- THEN all tournament entries SHALL have status `CONFIRMED`

### Scenario: Non-organizer cannot update another user's entry status

- GIVEN a user who is authenticated but is neither the entry owner nor an ORGANIZER
- WHEN they attempt to update an entry's status
- THEN the update SHALL be denied by RLS policy

### Scenario: Unauthenticated user cannot view entries

- GIVEN a user who is not authenticated
- WHEN they attempt to SELECT tournament entries
- THEN the query SHALL return zero rows (RLS blocks access)

---

## Migration Artifacts

| File | Purpose |
|------|---------|
| `supabase/migrations/00000000000002_entry_status.sql` | Creates `entry_status` enum and adds columns |
| `supabase/seed.sql` | Updated to set existing entries to `CONFIRMED` |
| `supabase/migrations/00000000000001_security_policies.sql` | Updated with RLS for status column |

---

## Data Integrity Constraints

| Constraint | Expression |
|------------|------------|
| Enum values | `'PENDING_PAYMENT'`, `'CONFIRMED'`, `'CANCELLLED'` |
| Default value | `'PENDING_PAYMENT'` |
| fee_amount_snap | Integer (cents, nullable) |
| Status NOT NULL | Entry must always have a status |

---

## Rollback

```sql
ALTER TABLE tournament_entries DROP COLUMN IF EXISTS status;
ALTER TABLE tournament_entries DROP COLUMN IF EXISTS fee_amount_snap;
DROP TYPE IF EXISTS entry_status;
```
