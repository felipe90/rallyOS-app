# Migration Index

Estado actualizado: 2026-03-30

## Resumen

```yaml
Total: 7
Completadas: 7
Pendientes: 0
```

---

## Migration Map

```yaml
00: init_schema.sql                   - Core Schema
01: security_policies.sql             - Security
02: add_elo_history.sql               - ELO Ledger
03: add_entry_status.sql              - Payment State
04: fix_offline_sync_trigger.sql      - Sync Security
05: implement_elo_calculation.sql     - ELO Calc
06: bracket_advancement.sql           - Brackets
```

---

## Detalle por Migration

### 00 - init_schema.sql
**Feature**: Core Schema  
**Fecha**: Antes de SDD

**Contenido**:
- Enums: sport_scoring_system, tournament_status, match_status, game_mode
- Tablas: sports, tournaments, categories, persons, athlete_stats
- Tablas: tournament_staff, tournament_entries, entry_members
- Tablas: matches, scores, payments, community_feed

**Notas**: Schema base sin el cual nada funciona

---

### 01 - security_policies.sql
**Feature**: Security  
**Fecha**: Pre-SDD

**Contenido**:
- `public_tournament_snapshot` view (PII-safe)
- RLS policies para scores, elo_history, matches, tournaments, tournament_staff
- Function: `check_offline_sync_conflict()`
- Function: `process_match_completion()`
- Function: `assign_tournament_creator_as_organizer()`
- Function: `rollback_match()`

**Bug conocido**: Columna `last_known_elo` no existía → corregido a `current_elo`

---

### 02 - add_elo_history.sql
**Feature**: ELO Ledger  
**SDD**: `fix-elo-history-table`

**Contenido**:
```sql
CREATE TYPE elo_change_type AS ENUM ('MATCH_WIN', 'MATCH_LOSS', 'ADJUSTMENT');

CREATE TABLE elo_history (
    id UUID PRIMARY KEY,
    person_id UUID REFERENCES persons(id) ON DELETE CASCADE,
    sport_id UUID REFERENCES sports(id) ON DELETE CASCADE,
    match_id UUID REFERENCES matches(id) ON DELETE SET NULL,
    previous_elo INTEGER NOT NULL,
    new_elo INTEGER NOT NULL,
    elo_change INTEGER NOT NULL,
    change_type elo_change_type NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_elo_history_person_sport ON elo_history(person_id, sport_id);
CREATE INDEX idx_elo_history_match ON elo_history(match_id);
```

**Tests**: Security TEST 2 PASS

---

### 03 - add_entry_status.sql
**Feature**: Payment State  
**SDD**: `add-entry-status`

**Contenido**:
```sql
CREATE TYPE entry_status AS ENUM ('PENDING_PAYMENT', 'CONFIRMED', 'CANCELLED');

ALTER TABLE tournament_entries ADD COLUMN status entry_status DEFAULT 'PENDING_PAYMENT' NOT NULL;
ALTER TABLE tournament_entries ADD COLUMN fee_amount_snap INTEGER;

CREATE POLICY "Entry owner or organizer can update status" ON tournament_entries FOR UPDATE ...;
```

**Tests**: Security TEST 6, 7 PASS

---

### 04 - fix_offline_sync_trigger.sql
**Feature**: Sync Security  
**SDD**: `fix-offline-sync-trigger`

**Contenido**:
```sql
CREATE TRIGGER trg_matches_conflict_resolution
BEFORE UPDATE ON matches
FOR EACH ROW EXECUTE FUNCTION check_offline_sync_conflict();

CREATE TRIGGER trg_scores_conflict_resolution
BEFORE UPDATE ON scores
FOR EACH ROW EXECUTE FUNCTION check_offline_sync_conflict();
```

**Tests**: TEST 4 PASS (ahora)

---

### 05 - implement_elo_calculation.sql
**Feature**: ELO Calculation  
**SDD**: `implement-elo-calculation`

**Contenido**:
```sql
CREATE OR REPLACE FUNCTION process_match_completion()
RETURNS TRIGGER SECURITY DEFINER
-- Calcula ELO cuando match.status = 'FINISHED'
-- INSERT a elo_history para winner y loser
-- UPDATE athlete_stats con nuevo ELO
```

**K-factor**:
```yaml
0-29 matches:   32
30-99 matches:  24
100+ matches:   16
```

**Tests**: ✅ Verificado manualmente

---

### 06 - bracket_advancement.sql
**Feature**: Bracket Advancement  
**SDD**: `implement-bracket-advancement`

**Contenido**:
```sql
CREATE OR REPLACE FUNCTION advance_bracket_winner()
RETURNS TRIGGER SECURITY DEFINER
-- Cuando match.status = 'FINISHED':
-- 1. Determina winner por sets_json
-- 2. Avanza winner a next_match_id
-- 3. Si next match completo → status = 'SCHEDULED'
```

**Tests**: ✅ Semi → Final advancement funciona

---

## Pendientes de Implementación

```yaml
Double Elimination:   Prioridad: Baja,  Complejidad: Alta
Round Robin:         Prioridad: Baja,  Complejidad: Alta
Real-time subs:      Prioridad: Media, Complejidad: Media
```

---

## Comandos Útiles

```bash
# Ver todas las migraciones aplicadas
psql ... -c "SELECT * FROM supabase_migrations.schema_migrations ORDER BY version;"

# Reset completo (borra todo y recrea)
supabase db reset

# Ver triggers
psql ... -c "SELECT tgname, tablename FROM pg_trigger WHERE tgname NOT LIKE 'pg_%';"

# Ver RLS policies
psql ... -c "SELECT tablename, policyname, cmd FROM pg_policies;"
```

---

## ADR Reference

```yaml
ELO como ledger:          adr/001-elo-ledger.md
Bracket como linked list: adr/002-bracket-linked-list.md
RLS con SECURITY DEFINER: adr/003-rls-security.md
```
