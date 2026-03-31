# MVP Tournament Flow - Proposal

## Change Name

`mvp-tournament-flow`

## Intent

Implement MVP tournament flow for RallyOS: free tournaments with registration, check-in, bracket generation, and match scoring. Excludes payment processing and mobile app.

## Scope

### In Scope
- Security: Person CRUD with RLS, duplicate registration prevention
- Tournament: Free flow, attendance check-in, bracket generation, match scoring
- Organization: Club management

### Out of Scope
- Payment processing (Stripe/MercadoPago)
- Mobile app (Expo/React Native)
- Admin global role
- Double elimination / round robin brackets

## Affected Areas

- `security`: RLS policies for persons, duplicate registration
- `tournament`: Free flow, attendance, bracket generation, match scoring
- `organization`: Club management

## Approach

### Phase 1: Security Base
1. Add RLS policies to `persons` table
2. Create trigger to prevent duplicate registration

### Phase 2: Core Tournament
3. Add `fee_amount` to tournaments, auto-confirm for free
4. Add attendance confirmation during CHECK_IN
5. Create bracket generation function

### Phase 3: Match Flow
6. Implement score entry with winner declaration
7. Triggers handle ELO calculation and bracket advancement

### Phase 4: Organization
8. Create `clubs` and `club_members` tables
9. Add club-based registration support

## Dependencies

- SPEC-005 (Person RLS) must complete before SPEC-006 (Duplicate Prevention)
- SPEC-001 (Free Flow) is foundation for SPEC-002, SPEC-003, SPEC-004

## Risks

- Bracket generation edge cases (bye placement, seeding)
- Race conditions during check-in period
