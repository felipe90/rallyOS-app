# RallyOS-App: Development Journal

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

| Test | Result |
|------|--------|
| TEST 1: Score RLS | ✅ PASS |
| TEST 2: ELO History Immutability | ✅ PASS |
| TEST 3: PII Leakage | ✅ PASS |
| TEST 4: Time-Tampering | ✅ PASS (after fix) |
| TEST 5: Staff Self-Elevation | ✅ PASS |
| TEST 6: Entry Status RLS | ✅ PASS |
| TEST 7: Entry Status Columns | ✅ PASS |

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
| Matches Played | K-Factor |
|----------------|----------|
| 0-29 | 32 |
| 30-99 | 24 |
| 100+ | 16 |

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

| Check | Result |
|-------|--------|
| Trigger created on matches | ✅ |
| Winner gets positive ELO | ✅ (+8 for test match) |
| Loser gets negative ELO | ✅ (-8 for test match) |
| K-factor varies by matches | ✅ |
| elo_history entries created | ✅ (2 entries per match) |
| athlete_stats updated | ✅ |

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

| Archivo | Descripción |
|---------|-------------|
| `docs/adr/001-elo-ledger.md` | ADR: ELO como ledger append-only |
| `docs/adr/002-bracket-linked-list.md` | ADR: Bracket como linked list |
| `docs/adr/003-rls-security.md` | ADR: RLS con SECURITY DEFINER |
| `docs/MIGRATION_INDEX.md` | Índice de todas las migraciones |
| `docs/ARCHITECTURE_DIAGRAMS.md` | Diagramas de flujo y seguridad |
| `docs/ER_DIAGRAM.md` | Diagrama ER completo |
| `docs/SEQUENCE_DIAGRAMS.md` | Diagramas de secuencia de negocio |

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

| Archivo | Cambio |
|---------|--------|
| `webdocs/icon.jpeg` | Copiado desde `ui/` |
| `webdocs/logo.png` | Copiado desde `ui/` |
| `webdocs/index.html` | Favicon actualizado + nombre con logo |
| `webdocs/README.md` | Header con logo centrado |

### Detalles Técnicos

- **Favicon**: Ahora usa `icon.jpeg` en vez de SVG con emoji
- **Navbar**: Nombre con `<img src="logo.png">` 
- **Home**: Logo centrado con `width="300"` sobre el título

### Importante

- `webdocs/` es documentación **local** (no se publica en GitHub)
- `docs/` sigue siendo symlink al knowledge base externo
- Server de docsify corre en `http://localhost:3000`

---

*Journal entry updated: 2026-03-30*
