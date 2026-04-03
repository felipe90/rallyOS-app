# Tasks: Security Hardening - RallyOS

## Overview

Implement 3 critical security fixes identified in the system evaluation.

## Phase 1: RLS on Sensitive Tables (SPEC-RLS-001)

- [x] 1.1 Enable RLS on `athlete_stats`
- [x] 1.2 Create SELECT policy for authenticated users
- [x] 1.3 Create UPDATE policy for own records only
- [x] 1.4 Enable RLS on `payments`
- [x] 1.5 Create SELECT policy (own payments + organizer view)
- [x] 1.6 Create INSERT policy (block direct inserts)
- [x] 1.7 Create UPDATE policy (organizer only for status)
- [x] 1.8 Enable RLS on `match_sets`
- [x] 1.9 Create SELECT policy for authenticated users
- [x] 1.10 Create INSERT/UPDATE/DELETE policies (block direct access)
- [x] 1.11 Run verification queries

## Phase 2: SECURITY DEFINER on RPCs (SPEC-RPC-001)

- [x] 2.1 Add SECURITY DEFINER to `create_round_robin_group`
- [x] 2.2 Add SECURITY DEFINER to `generate_round_robin_matches`
- [x] 2.3 Add SECURITY DEFINER to `offer_third_place`
- [x] 2.4 Add SECURITY DEFINER to `accept_third_place`
- [x] 2.5 Add SECURITY DEFINER to `create_third_place_match`
- [x] 2.6 Add SECURITY DEFINER to `get_match_loser`
- [x] 2.7 Add SECURITY DEFINER to `assign_staff`
- [x] 2.8 Add SECURITY DEFINER to `invite_staff`
- [x] 2.9 Add SECURITY DEFINER to `generate_referee_suggestions`
- [x] 2.10 Add SECURITY DEFINER to `validate_score`
- [x] 2.11 Add `SET search_path TO extensions, public` to all
- [x] 2.12 Verify all have explicit authorization checks
- [x] 2.13 Run verification queries

## Phase 3: elo_history Trigger (SPEC-ELO-001)

- [x] 3.1 Add `last_match_id` column to `athlete_stats`
- [x] 3.2 Create `fn_record_elo_change()` trigger function
- [x] 3.3 Create `trg_record_elo_change` trigger
- [x] 3.4 Enable RLS on `elo_history`
- [x] 3.5 Create SELECT policies for users + organizers
- [x] 3.6 Update ELO calculation to set `last_match_id`
- [x] 3.7 Test trigger with sample ELO update
- [x] 3.8 Verify records appear in elo_history

## Phase 4: Testing & Verification

- [x] 4.1 Run security test suite
- [x] 4.2 Run integration test suite
- [x] 4.3 Run new RLS tests
- [x] 4.4 Test RPC calls with auth
- [x] 4.5 Test trigger records elo_history

## Phase 5: Documentation

- [ ] 5.1 Update DEVELOPMENT_JOURNEY.md
- [ ] 5.2 Update schema.md with new columns
- [ ] 5.3 Document security model
