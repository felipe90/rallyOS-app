# DEVELOPMENT JOURNEY: rallyOS

This document serves as the development log for the **rallyOS** project, a sports tournament management platform with an Offline-First approach.

## 📌 Philosophy: Spec-Driven Development (SDD)
This development is primarily driven by **Spec-Driven Development**. For this reason, the entire initial stage is 100% dedicated to refining the domain model, analyzing constraints, orchestrating database security, and devising the technical business logic exhaustively, mitigating architectural risks theoretically *before* typing a single line of GUI code.

## Day 1: Architectural Definition and Modeling (March 26, 2026)

**Objective:** Establish the architectural foundations and robust database schemas before implementing UI or Backend.

### Core Architectural Decisions
1. **"Frontend-Hero" Tech Stack**:
   *   React Native (Expo) for hybrid mobile development.
   *   Supabase (PostgreSQL, Auth, Realtime) as Backend-as-a-Service, delegating access and authentication logic.
   *   TanStack Query v5 + SQLite/AsyncStorage to guarantee local availability without internet.

2. **Offline-First Model & Optimistic UI**:
   *   The calculation of **ELO** and business logic (Handicap, Bracket advancement) will operate temporarily on the client to provide instantaneous *Optimistic UI* to the user, without loading spinners.

### Physical Database Design and Mitigations
The relational schema (`DATABASE_DESIGN_V2.md` / `DOMAIN_MODEL_V2.md`) was debugged, reaching the Third Normal Form (3NF) and Domain-Driven Design:
*   **Match/Score Isolation:** Strict 1:1 relationship managed via an `UNIQUE` constraint on the scores table to prevent circular locks in the DB.
*   **Bracket Logic (Linked List):** Each `match` points to its `next_match_id` to build visual brackets (Tournaments) with a single SQL query.
*   **Immutable Ledger:** `elo_history` was defined as the untouchable (Append-Only) record to generate calculations and auditable graphs.
*   **Tournament Entries (Ephemeral):** The rigid concept of "Team" was eliminated, using temporary entries tied to the Tournament, improving the software's pragmatism compared to sports reality.

### Security and Consistency
*   **Supabase RLS and Triggers:** Due to the *Fat Client* nature, we will validate database writes by limiting with `ROW LEVEL SECURITY`: `auth.uid() = referee_id`.
*   **Offline Conflict Prevention:** Implemented the *Last-Write-Wins* pattern via `local_updated_at` to reject temporal collisions when devices regain the internet.
*   **Data Leakage Prevention:** Creation of `public_tournament_snapshot`, a read-only view free of PII (Personally Identifiable Information like emails/phones), preventing unauthorized downloading via TanStack Query Snapshots.

### Architectural Pivot: Open Roles and UUID Mismatch
During the interactive design review, we discovered that the "External Referee" model was too lax and technically failed:
1. The `referee_id` in matches pointed to the sports profile (`persons.id`), causing the RLS security policy (`auth.uid() = referee_id`) to systematically fail.
2. It allowed any app user to be assigned as a referee regardless of whether the organizers authorized it or not.

**Applied Solution:**
*   Created the authorization domain `TournamentStaff`. Now only users with a role (`ORGANIZER` or `EXTERNAL_REFEREE`) linked to a specific tournament can interact administratively with the matches (*Constraint* reinforced with RLS and subqueries in Supabase).
*   Modified all `referee_id` keys to point to the Security infrastructure layer (`auth.users(id)`).

## Day 1 (Night): From Manager to SaaS Platform - Payment Engine (March 26, 2026)
The business logic schema was designed to integrate the payment gateway (Stripe / Mercado Pago), documented in `design/PAYMENTS_BUSINESS_LOGIC.md`.

**Design Decisions:**
*   **Payment State Machine:** Implemented over `tournament_entries`. The tournament bracket now IGNORES registrations that are in the `PENDING_PAYMENT` state.
*   **Secure Webhooks:** Financial validation will be isolated in *Supabase Edge Functions*, protecting the database from fat clients (mobile).

## Day 1 (Final): Enterprise Security Mitigations
With the goal of bringing RallyOS to a secure corporate grade, advanced risk vectors were evaluated and direct mitigations were deployed at the database layer (`schema_security.sql`):
1.  **Abolition of Manual Payments:** The possibility of recording "CASH_MANUAL" income was removed to prevent cash fraud by local organizers. The platform is 100% dependent on the online gateway for income validation.
2.  **Time-Tampering Protection:** The offline synchronization function now blocks any attempt to overwrite data with "future" dates (e.g., advancing the phone clock), shielding the *Last-Write-Wins* pattern.
3.  **Strict DDL Authorization:** Only the platform or the creator of a tournament can be assigned as the initial `ORGANIZER`, and only an organizer can invite more *Staff*, applying hard `ROW LEVEL SECURITY` on delegate insertion.
4.  **Panic Button ("Undo Match"):** Created the stored procedure `rollback_match(id)` that allows an organizer to revert a mistakenly finished match, clearing future brackets and leaving the ELO accounting layer ready for recalculations.

## Day 2: Engagement and Virality (Social Feed)
Defined the architectural design for community social events to foster retention (documented in `design/SOCIAL_SHARING_ARCHITECTURE.md`).

**Design Decisions:**
*   **Event-Driven Approach:** All relevant activity (Upsets, new tournaments, champions) will be recorded as a JSON payload in the structured `community_feed` table.
*   **"Spotify Wrapped" Export:** Opted for client-side UI development (rendering views to PNG in Expo) combined with Server-Side capture in Edge Functions (Open Graph Unfurling via WebLinks) to inject organic advertising through players' Instagram stories and WhatsApp groups.

## Day 2 (Late): Context Future-Proofing (English Translation)
Following the Spec-Driven Development philosophy and aiming for a future-proofed codebase, a decision was made to translate 100% of the architectural documentation, design specs, and SQL comments from Spanish to English. This ensures standard B2B/Enterprise practices and broader collaboration capabilities.

## Day 3: Ruthless Architectural Overhaul (March 31, 2026)

**Objective:** Fix critical logic flaws and data modeling "smells" identified during the architectural audit.

### 1. The "Real" ELO Engine
Discovered that the previous ELO implementation was a placeholder that always assumed Entry A won.
*   **Applied Solution:** Rewrote the `process_match_completion` trigger to perform real set-by-set comparison. It now correctly identifies the winner and applies the standard ELO formula with dynamic K-Factors (32/24/16) based on player experience.

### 2. Deterministic Bracket Advancement
The "First Empty Slot" pattern was identified as a major risk for bracket integrity.
*   **Applied Solution:** Introduced `winner_to_slot` (ENUM 'A', 'B') in the `matches` table. The `advance_bracket_winner` trigger now places winners in precisely defined slots, ensuring the bracket remains structurally sound even with manual overrides or sync delays.

### 3. Data Normalization (Sets)
The use of `JSONB` for match sets was flagged as "lazy modeling" that would hinder future performance and statistics.
*   **Applied Solution:** Eliminated `scores.sets_json` and implemented a fully relational `match_sets` table. This provides SQL-native integrity and simplifies the synchronization of individual set results in an offline-first environment.

### 4. Identity Consolidation
Refined the relationship between `persons` (Athletes) and `auth.users` (Identity).
*   **Applied Solution:** Enforced a 1:1 unique constraint on `persons.user_id` to prevent identity fragmentation. The system now treats `persons` as the master profile for all athletic context, whether linked to a registered account or existing as a "Shadow Profile".

## Day 3 (Evening): Engagement & Integrity (Gamification & PIN Referee)

**Objective:** Transform RallyOS from a management tool into a social SaaS with self-sustaining operational logic.

### 1. Gamification & Ranks
Implemented a progression system to drive player retention.
*   **Applied Solution:** Defined 5 ELO-based ranks (Bronze to Diamond) and established a ledger for automated achievements. Created a trigger to auto-adjust ranks on every match completion, providing immediate feedback to the player.

### 2. PIN-Based Self-Refereeing (The "Invisible Referee")
Addressed the operational cost of tournaments by enabling players to report scores securely.
*   **Applied Solution:** Implemented a `pin_code` system for matches. Each match now generates a unique 4-digit PIN. Players can only submit scores if they provide this PIN (ensuring physical presence), while tournament staff retain administrative bypass capabilities.

### 3. Identity Integrity Baseline
Set the stage for future anti-smurfing measures.
*   **Applied Solution:** Documented the "Trusted Athlete" roadmap, prioritizing social validation and ELO anomaly detection for the next phase of development.

### 4. Localization & Global Readiness
Prepared the platform for international expansion.
*   **Applied Solution:** Implemented the `countries` master table and linked all core entities (Players, Clubs, Tournaments) to their respective geographic regions. Seeded the database with 8 major markets (COL, ARG, MEX, ESP, etc.), enabling country-based filtering and public nationality flags.

---
*Current state: Backend architecture is 100% "Global Ready" and operationally autonomous. Ready for App Implementation. (March 31, 2026)*



