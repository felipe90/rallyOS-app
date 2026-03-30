# ADR-001: ELO como Ledger Append-Only

## Status
**Accepted** — 2026-03-30

## Context

Necesitábamos tracking de cambios de rating ELO para jugadores con las siguientes requerimientos:
- Auditoría completa de todos los cambios
- Reversión posible si hay errores de cálculo
- Histórico persistente del jugador
- Immutable: nadie puede modificar el pasado

## Decision

Usamos una tabla `elo_history` como ledger append-only.

```sql
CREATE TABLE elo_history (
    id UUID PRIMARY KEY,
    person_id UUID REFERENCES persons(id),
    sport_id UUID REFERENCES sports(id),
    match_id UUID REFERENCES matches(id),
    previous_elo INTEGER NOT NULL,
    new_elo INTEGER NOT NULL,
    elo_change INTEGER NOT NULL,
    change_type elo_change_type NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Restricciones**:
- INSERT only — no UPDATE ni DELETE via RLS
- Solo triggers `SECURITY DEFINER` pueden escribir
- Clientes pueden solo SELECT

## Rationale

1. **Auditoría completa**: Cada cambio de ELO queda registrado con timestamp y razón
2. **Reversión**: Si un match se deshace, se puede consultar el historial
3. **Analytics**: Se puede reconstruir el progreso de un jugador
4. **Debugging**: Errores de cálculo son rastreables

**Alternativas consideradas**:
- Calcular ELO on-demand: ❌ Pierde histórico, no hay auditoría
- Event sourcing: ⚠️ Overkill para este caso de uso
- Immutable ledger: ✅ Ideal pero más complejo

## Consequences

**Positive**:
- Trazabilidad completa de cambios
- Posibilidad de rollback de ELO
- Histórico consultable para analytics

**Negative**:
- Queries más complejas (JOIN con elo_history vs solo athlete_stats)
- Más storage usado
- Trigger adicional en writes

## Implementation Notes

- K-factor: 32 (<30 matches), 24 (30-100), 16 (>100)
- Fórmula: `New ELO = Old + K × (1 - Expected)`
- Trigger: `process_match_completion` (AFTER UPDATE on matches)
