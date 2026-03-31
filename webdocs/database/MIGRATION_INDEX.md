# Migration Index

Estado actualizado: 2026-03-31

## Resumen

```yaml
Total: 25
Completadas: 25
Pendientes: 0
```

---

## Migration Map

```yaml
0000: init_schema.sql                   - Core Schema
19: architectural_overhaul.sql        - Normalization & Identity
20: real_elo_engine.sql               - PRO ELO Engine
21: deterministic_brackets.sql        - Deterministic Logic
22: engagement_tables.sql             - Gamification
23: pin_logic.sql                     - Self-Refereeing
24: localization_schema.sql           - Global Ready
25: seed_countries.sql                 - L10N Data
```

---

## Detalle por Migration

### 19 - architectural_overhaul.sql
**Feature**: Architecture Audit / Overhaul
**SDD**: `architectural-overhaul`

**Contenido**:
- Normalización de `match_sets` (Relacional).
- Unificación de Identidad (Persons 1:1 Auth User).
- Slots Determinísticos (`winner_to_slot`).

---

### 20/21 - ELO & Bracket Logic
**Feature**: Core Tournament Logic
**SDD**: `real-elo-engine`, `deterministic-brackets`

**Contenido**:
- `process_match_completion()`: REAL ELO comparison based on sets.
- `advance_bracket_winner()`: Deterministic slot assignment.

---

### 22/23 - Engagement & Integrity
**Feature**: Gamification & Self-Refereeing
**SDD**: `mvp-gamification-and-refereeing`

**Contenido**:
- Tablas: `achievements`, `player_achievements`.
- Enums: `athlete_rank`.
- Trigger: `trg_generate_match_pin` (4-digit security code).

---

### 24/25 - Localization
**Feature**: Global Readiness (L10N)
**SDD**: `localization`

**Contenido**:
- Tabla: `countries` (ISO, Flag, Currency).
- Links: `persons.nationality`, `clubs.country`, `tournaments.country`.
- Seed: Colombia, Argentina, México, España, USA, Brasil, Chile, Perú.

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
