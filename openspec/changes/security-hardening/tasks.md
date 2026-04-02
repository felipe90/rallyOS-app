# Tasks: Security Hardening - RallyOS

## Overview

Implement 3 critical security fixes identified in the system evaluation.

## Phase 1: RLS on Sensitive Tables (SPEC-RLS-001)

- [ ] 1.1 Enable RLS on `athlete_stats`
- [ ] 1.2 Create SELECT policy for authenticated users
- [ ] 1.3 Create UPDATE policy for own records only
- [ ] 1.4 Enable RLS on `payments`
- [ ] 1.5 Create SELECT policy (own payments + organizer view)
- [ ] 1.6 Create INSERT policy (block direct inserts)
- [ ] 1.7 Create UPDATE policy (organizer only for status)
- [ ] 1.8 Enable RLS on `match_sets`
- [ ] 1.9 Create SELECT policy for authenticated users
- [ ] 1.10 Create INSERT/UPDATE/DELETE policies (block direct access)
- [ ] 1.11 Run verification queries

## Phase 2: SECURITY DEFINER on RPCs (SPEC-RPC-001)

- [ ] 2.1 Add SECURITY DEFINER to `create_round_robin_group`
- [ ] 2.2 Add SECURITY DEFINER to `generate_round_robin_matches`
- [ ] 2.3 Add SECURITY DEFINER to `offer_third_place`
- [ ] 2.4 Add SECURITY DEFINER to `accept_third_place`
- [ ] 2.5 Add SECURITY DEFINER to `create_third_place_match`
- [ ] 2.6 Add SECURITY DEFINER to `get_match_loser`
- [ ] 2.7 Add SECURITY DEFINER to `assign_staff`
- [ ] 2.8 Add SECURITY DEFINER to `invite_staff`
- [ ] 2.9 Add SECURITY DEFINER to `generate_referee_suggestions`
- [ ] 2.10 Add SECURITY DEFINER to `validate_score`
- [ ] 2.11 Add `SET search_path TO extensions, public` to all
- [ ] 2.12 Verify all have explicit authorization checks
- [ ] 2.13 Run verification queries

## Phase 3: elo_history Trigger (SPEC-ELO-001)

- [ ] 3.1 Add `last_match_id` column to `athlete_stats`
- [ ] 3.2 Create `fn_record_elo_change()` trigger function
- [ ] 3.3 Create `trg_record_elo_change` trigger
- [ ] 3.4 Enable RLS on `elo_history`
- [ ] 3.5 Create SELECT policies for users + organizers
- [ ] 3.6 Update ELO calculation to set `last_match_id`
- [ ] 3.7 Test trigger with sample ELO update
- [ ] 3.8 Verify records appear in elo_history

## Phase 4: Testing & Verification

- [ ] 4.1 Run security test suite
- [ ] 4.2 Run integration test suite
- [ ] 4.3 Run new RLS tests
- [ ] 4.4 Test RPC calls with auth
- [ ] 4.5 Test trigger records elo_history

## Phase 5: Documentation

- [ ] 5.1 Update DEVELOPMENT_JOURNEY.md
- [ ] 5.2 Update schema.md with new columns
- [ ] 5.3 Document security model
