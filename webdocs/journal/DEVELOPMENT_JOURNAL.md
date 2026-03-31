# RallyOS-App: Development Journal

> **Único source of truth (SSO)** — Este es el journal oficial del proyecto.

---

## 2026-03-30 — Architecture Review & Critical Fixes

### Session Overview

Completed a comprehensive architecture review and fixed 2 critical database schema issues.

### Issues Fixed

#### 1. Missing `elo_history` Table 🔴 CRITICAL
- **Problem**: Table referenced in security policies and triggers but never created in schema
- **Impact**: Migration `00000000000001_security_policies.sql` would fail
- **Solution**: Created migration `00000000000002_add_elo_history.sql`
- **Implementation**:
  - Created `elo_change_type` enum (MATCH_WIN, MATCH_LOSS, ADJUSTMENT)
  - Created `elo_history` table with proper FK constraints
  - Added indexes for query performance
- **Verification**: ✅ Security TEST 2 PASS

#### 2. Missing `entry_status` Field 🔴 CRITICAL
- **Problem**: Payment flow required state machine but `tournament_entries` had no status column
- **Impact**: Payment confirmation couldn't update entry status
- **Solution**: Created migration `00000000000003_add_entry_status.sql`
- **Implementation**:
  - Created `entry_status` enum (PENDING_PAYMENT, CONFIRMED, CANCELLED)
  - Added `status` column with default PENDING_PAYMENT
  - Added `fee_amount_snap` for price locking
  - Added RLS policy for UPDATE (owner OR organizer only)
- **Verification**: ✅ Security TEST 6 & 7 PASS

#### 3. Offline Sync Trigger Attachment ⚠️ MEDIUM
- **Problem**: `check_offline_sync_conflict` function existed but triggers not attached
- **Impact**: Time-tampering protection not working
- **Solution**: Created migration `00000000000004_fix_offline_sync_trigger.sql`
- **Implementation**:
  - Created `trg_matches_conflict_resolution` trigger on matches
  - Created `trg_scores_conflict_resolution` trigger on scores
- **Verification**: ✅ Future timestamps blocked, older timestamps rejected

### Files Created

```
supabase/migrations/
├── 00000000000002_add_elo_history.sql
├── 00000000000003_add_entry_status.sql
└── 00000000000004_fix_offline_sync_trigger.sql

docs/
└── ARCHITECTURE_REVIEW.md

openspec/changes/
├── fix-elo-history-table/
│   ├── proposal.md
│   ├── spec.md
│   └── tasks.md
├── add-entry-status/
│   ├── proposal.md
│   ├── spec.md
│   └── tasks.md
└── fix-offline-sync-trigger/
    ├── proposal.md
    ├── spec.md
    └── tasks.md
```

### Files Modified

```
supabase/migrations/00000000000001_security_policies.sql
supabase/seed.sql
supabase/tests/security_tests.sql
```

### Security Test Results

```yaml
TEST 1: Score RLS               ✅ PASS
TEST 2: ELO History Immutability ✅ PASS
TEST 3: PII Leakage             ✅ PASS
TEST 4: Time-Tampering          ✅ PASS (after fix)
TEST 5: Staff Self-Elevation    ✅ PASS
TEST 6: Entry Status RLS        ✅ PASS
TEST 7: Entry Status Columns    ✅ PASS
```

### Next Steps

1. ~~Implement ELO calculation in `process_match_completion` trigger~~ ✅ DONE
2. Implement bracket advancement logic
3. Start mobile app implementation
4. Implement payment webhook handlers

---

## 2026-03-30 (Tarde) — ELO Calculation Implemented

### Session Overview

Implemented the ELO calculation trigger that automatically updates player ratings when matches finish.

### Implementation Details

#### `process_match_completion` Trigger
- **Location**: `supabase/migrations/00000000000005_implement_elo_calculation.sql`
- **Security**: SECURITY DEFINER (bypasses RLS for elo_history inserts)
- **Trigger**: Fires AFTER UPDATE on `matches` when status changes to FINISHED

#### ELO Algorithm
```
Expected Score = 1 / (1 + 10^((Opponent - Rating) / 400))
K-Factor = 32 (<30 matches), 24 (30-100 matches), 16 (>100 matches)
New Rating = Old Rating + K * (Actual Score - Expected Score)
```

#### K-Factor Implementation
```yaml
0-29 matches:   K = 32
30-99 matches:  K = 24
100+ matches:   K = 16
```

### What Happens on Match Completion

1. Get winner/loser from entry members
2. Fetch current ELO and match count for both
3. Calculate expected score using opponent's rating
4. Calculate ELO change using K-factor
5. Insert `elo_history` entries for both players
6. Update `athlete_stats` for both players

### Files Created

```
supabase/migrations/
└── 00000000000005_implement_elo_calculation.sql

openspec/changes/
└── implement-elo-calculation/
    ├── proposal.md
    ├── spec.md
    └── tasks.md
```

### Verification

```yaml
Trigger created on matches:   ✅
Winner gets positive ELO:    ✅ (+8 for test match)
Loser gets negative ELO:     ✅ (-8 for test match)
K-factor varies by matches:   ✅
elo_history entries created:  ✅ (2 entries per match)
athlete_stats updated:       ✅
```

### Test Example
- Winner: 1000 ELO → 1008 (+8)
- Loser: 800 ELO → 792 (-8)
- K-factor: 32 (0 matches played)
- Expected score: 0.76
- Change: 32 × (1 - 0.76) = 7.68 ≈ 8

---

## 2026-03-30 (Tarde 2) — Documentación de Arquitectura

### Session Overview

Implementamos documentación completa para no perdernos en el proyecto.

### Documentos Creados

```yaml
docs/adr/001-elo-ledger.md:      ADR: ELO como ledger
docs/adr/002-bracket-linked-list.md: ADR: Bracket como linked list
docs/adr/003-rls-security.md:    ADR: RLS con SECURITY DEFINER
docs/MIGRATION_INDEX.md:         Índice de migraciones
docs/ARCHITECTURE_DIAGRAMS.md:   Diagramas de flujo
docs/ER_DIAGRAM.md:             Diagrama ER
docs/SEQUENCE_DIAGRAMS.md:      Diagramas de secuencia
```

### Diagramas de Secuencia Implementados

1. **ELO Calculation on Match Completion** — Flujo completo
2. **Bracket Advancement** — Winner avanza al siguiente match
3. **Entry Registration with Payment** — Flujo completo
4. **Tournament Creation with Auto-Organizer** — Trigger automático
5. **Offline Sync Conflict Resolution** — Time-tampering protection
6. **Match Score Update (RLS)** — Verificación de permisos

### Reglas Establecidas

```
Después de cada change:

1. Actualizar docs/ARCHITECTURE_DIAGRAMS.md
2. Crear ADR en docs/adr/ si hay decisión nueva
3. Comment WHY en código complejo
4. Tests para todo lo nuevo
```

---

## 2026-03-30 (Noche) — Branding Docsify

### Session Overview

Agregamos branding visual a la documentación local con el logo de RallyOS.

### Cambios Realizados

```yaml
webdocs/icon.jpeg:   Copiado desde ui/
webdocs/logo.png:    Copiado desde ui/
webdocs/index.html:  Favicon + logo en navbar
webdocs/README.md:   Header con logo centrado
```

### Detalles Técnicos

- **Favicon**: Ahora usa `icon.jpeg` en vez de SVG con emoji
- **Navbar**: Nombre con `<img src="logo.png">` 
- **Home**: Logo centrado con `width="300"` sobre el título

### Importante

- `webdocs/` es documentación **local** (no se publica en GitHub)
- `docs/` sigue siendo symlink al knowledge base externo
- Server de docsify corre en `http://localhost:3000`

---

## 2026-03-30 (Noche 2) — SPEC-005: Person RLS

### Session Overview

Implementamos RLS en la tabla `persons` siguiendo el workflow SDD.

### Specs Creados

```yaml
openspec/changes/mvp-tournament-flow/
├── proposal.md
├── specs/
│   ├── security/person-rls.md      (SPEC-005)
│   ├── security/duplicate-registration.md  (SPEC-006)
│   ├── tournament/free-flow.md    (SPEC-001)
│   ├── tournament/attendance.md   (SPEC-002)
│   ├── tournament/bracket-generation.md (SPEC-003)
│   ├── tournament/match-scoring.md (SPEC-004)
│   └── organization/club-management.md (SPEC-007)
└── design.md
```

### Implementación SPEC-005

| Policy | Command | Description |
|--------|---------|-------------|
| Persons are readable... | SELECT | Todos usuarios autenticados |
| Users can create own... | INSERT | Propio user_id o NULL (guest) |
| Users can update own... | UPDATE | Solo user_id propio |
| Users can delete own... | DELETE | Solo user_id propio |

### Files Created

```
supabase/migrations/
└── 00000000000008_add_persons_rls.sql
```

### Verification

```bash
# RLS habilitado
# Result: 4 rows ✅
```

---

## 2026-03-30/31 — MVP Specs Implementados

### Specs Completados

```yaml
SPEC-001: Free Tournament Flow
SPEC-002: Attendance/Check-In  
SPEC-003: Bracket Generation
SPEC-004: Match Score Entry
SPEC-005: Person CRUD con RLS
SPEC-006: Prevent Duplicate Registration
SPEC-007: Club Management
```

### Migrations Creadas

```yaml
00000000000008: add_persons_rls.sql        - RLS policies for persons
00000000000009: prevent_duplicate_registration.sql - Trigger anti-duplicate
00000000000010: free_tournament_flow.sql   - fee_amount + auto-confirm
00000000000011: attendance_checkin.sql     - checked_in_at + validation
00000000000012: bracket_generation.sql    - generate_bracket() function
00000000000013: match_score_entry.sql      - Docs (ya existía)
00000000000014: club_management.sql         - clubs + club_members tables
```

### Features Implementadas

```yaml
Tournament: fee_amount, auto-confirm, status transitions
Attendance: checked_in_at, attendance validation, bracket lock
Bracket: generate_bracket() con seeding ELO, BYE handling
Clubs: clubs CRUD, club_members, club_id en entries
Security: RLS en persons, duplicate prevention
```

---

## 2026-03-31 — CRUD Specs + Use Cases

### CRUD Specs Creados

```yaml
SPEC-008: Sports CRUD con RLS
SPEC-009: Categories CRUD con RLS
SPEC-010: Tournament Entries CRUD
SPEC-011: Community Feed
```

### Use Cases Verbose Creados

```yaml
CU-01: Organizador Crea Torneo
CU-02: Jugador se Registra en Torneo
CU-03: Organizador Confirma Asistencia (Check-In)
CU-04: Organizador Genera Bracket
CU-05: Árbitro Ingresa Scores
CU-06: Sistema Calcula ELO Automáticamente
CU-07: Ganador Avanza al Siguiente Partido
CU-08: Organizador Cierra Torneo
CU-09: Jugador Ve su Perfil y Estadísticas
CU-10: Jugador Ve Feed de Actividad
```

### Estructura de Specs

```
openspec/changes/mvp-tournament-flow/
├── specs/
│   ├── security/        (SPEC-005, 006)
│   ├── tournament/       (SPEC-001, 002, 003, 004, CU01-CU08)
│   ├── organization/    (SPEC-007, CU10)
│   ├── security/        (SPEC-005, 006, CU09)
│   └── crud/           (SPEC-008, 009, 010, 011)
└── usecases/           (CU-01 al CU-10)
```

### Migrations CRUD

```yaml
00000000000015: sports_crud.sql        - RLS for sports
00000000000016: categories_crud.sql   - RLS for categories
00000000000017: entries_crud.sql      - RLS for entries + entry_members
00000000000018: community_feed.sql    - Feed RLS + auto-events
```

### Specs Convertidos de Use Cases

```yaml
CU01: Tournament Creation
CU02: Registration
CU03: Attendance
CU04: Bracket Generation
CU05: Score Entry
CU06: ELO Calculation
CU07: Bracket Advancement
CU08: Tournament Closure
CU09: Profile Management
CU10: Activity Feed
```

---

## 2026-03-31 — Testing & Verification

### Test Results

| Aspect | Status | Notes |
|--------|--------|-------|
| RLS Tables | ✅ 13/15 | athlete_stats y payments son N/A |
| RLS Policies | ✅ 35 | Todas creadas |
| Business Triggers | ✅ 9 | Triggers de negocio activos |
| New Columns | ✅ 4 | fee_amount, checked_in_at, club_id, bracket_generated |
| New Tables | ✅ 2 | clubs, club_members |
| Specs | ✅ 21 | Todos creados |
| Use Cases | ✅ 10 | Verbose completos |
| Migrations | ✅ 18 | Todas aplicadas |

### RLS Coverage

| Table | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| sports | ✅ | ✅ | ✅ | ✅ |
| tournaments | ✅ | ✅ | - | - |
| categories | ✅ | ✅ | ✅ | ✅ |
| persons | ✅ | ✅ | ✅ | ✅ |
| tournament_entries | ✅ | ✅ | ✅ | ✅ |
| entry_members | ✅ | ✅ | - | ✅ |
| matches | ✅ | ✅ | ✅ | ✅ |
| scores | ✅ | ✅ | ✅ | ✅ |
| elo_history | ✅ | - | - | - |
| community_feed | ✅ | ✅ | - | ✅ |
| clubs | ✅ | ✅ | ✅ | ✅ |
| club_members | ✅ | ✅ | - | ✅ |

### Active Triggers

```yaml
trg_prevent_duplicate_registration    - entry_members
trg_auto_confirm_free_entry          - tournament_entries
trg_validate_attendance_change       - tournament_entries
trg_validate_category_delete         - categories
trg_feed_entry_registered          - tournament_entries
trg_advance_bracket                 - matches
trg_match_completion                - matches
trg_matches_conflict_resolution     - matches
trg_scores_conflict_resolution      - scores
```

### MVP Backend Status

```yaml
Security (RLS):     ✅ Completado
Tournament Flow:     ✅ Completado
Bracket System:     ✅ Completado
ELO Calculation:    ✅ Completado
Clubs:              ✅ Completado
Community Feed:     ✅ Completado
─────────────────────────────
MVP Backend:        ✅ LISTO
```

---

*Journal entry updated: 2026-03-31*





