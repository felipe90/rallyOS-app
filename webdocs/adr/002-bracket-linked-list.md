# ADR-002: Bracket como Linked List

## Status
**Accepted** — 2026-03-30

## Context

Necesitábamos representar el bracket de un torneo de eliminación simple donde:
- Matches tienen posiciones fijas (Semifinal 1, Semifinal 2, Final, etc.)
- El ganador de un match avanza al siguiente match
- La estructura del bracket se define al crear el torneo

## Decision

Usamos una linked list via `next_match_id` en la tabla `matches`.

```sql
ALTER TABLE matches ADD COLUMN next_match_id UUID REFERENCES matches(id);
```

**Lógica**:
- Cada match sabe cuál es su "siguiente" match en el bracket
- Cuando un match termina, el trigger avanza al ganador
- El orden de entrada (entry_a vs entry_b) determina la ranura en el siguiente match

```
Semifinal 1 → Winner → Final (entry_a)
Semifinal 2 → Winner → Final (entry_b)
```

## Rationale

1. **Simplicidad**: No requiere queries recursivas complejas
2. **Eficiencia**: O(1) para avanzar de ronda
3. **Predecibilidad**: El bracket se define upfront, no cambia

**Alternativas consideradas**:
- Árbol auto-generado: ⚠️ Más flexible pero más complejo
- Recursive CTE: ❌ Queries lentas en tournaments grandes
- Matriz de brackets: ⚠️ Overhead para el caso de uso

## Consequences

**Positive**:
- Avance de bracket en O(1)
- Estructura simple de entender
- FK constraint garantiza integridad referencial

**Negative**:
- Difícil de reordenar una vez definido
- No soporta Double Elimination sin cambios
- Circular references posibles (mitigado con CHECK constraint)

## Implementation Notes

- Trigger: `advance_bracket_winner` (AFTER UPDATE on matches)
- Determina ganador por sets_json (quien ganó más sets)
- Coloca al ganador en la primera ranura libre (entry_a o entry_b)
- Si ambas ranuras llenas → status = 'SCHEDULED'

## Rollback

```sql
UPDATE matches SET next_match_id = NULL;
```
