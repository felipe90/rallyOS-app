# ADR-003: RLS con SECURITY DEFINER para Triggers

## Status
**Accepted** — 2026-03-30

## Context

Necesitábamos un modelo de seguridad donde:
- Clientes (app móvil) pueden escribir solo en tablas específicas
- Triggers del servidor pueden escribir a tablas "protegidas"
- El sistema de ELO es inmutable para clientes

## Decision

Usamos Row Level Security (RLS) con `SECURITY DEFINER` en triggers.

```sql
-- Tabla protegida: elo_history
ALTER TABLE elo_history ENABLE ROW LEVEL SECURITY;

-- Policy: solo SELECT para todos
CREATE POLICY "Elo history is read only for users" 
ON elo_history FOR SELECT USING (true);

-- NO INSERT/UPDATE/DELETE policy → clientes bloqueados

-- Trigger usa SECURITY DEFINER para bypasear RLS
CREATE FUNCTION process_match_completion()
RETURNS TRIGGER SECURITY DEFINER
```

## Rationale

1. **Defensa en profundidad**: Dos capas de seguridad
2. **Server-side authority**: Solo código del servidor modifica ELO
3. **Auditoría implícita**: Si el trigger corre, el cambio es válido

**Flujo de seguridad**:
```
Client → RLS Check (¿puede escribir?) → SECURITY DEFINER (¿es trigger?)
                                         → SI → Escribe a elo_history
                                         → NO → Bloqueado
```

## Consequences

**Positive**:
- Clientes no pueden modificar ELO directamente
- Triggers tienen acceso garantizado
- Modelo de permisos granular

**Negative**:
- SECURITY DEFINER requiere cuidado (privilegios elevados)
- Debugging de permisos más complejo
- Rollback manual si trigger falla

## Security Model

| Tabla | Client SELECT | Client INSERT | Client UPDATE | Trigger |
|-------|--------------|---------------|--------------|---------|
| `elo_history` | ✅ | ❌ | ❌ | ✅ |
| `scores` | ✅ | ✅ (referee) | ✅ (referee) | ✅ |
| `matches` | ✅ | ✅ (staff) | ✅ (staff) | ✅ |
| `athlete_stats` | ✅ | ❌ | ❌ | ✅ |

## Implementation Notes

- Owner de funciones: `supabase_admin` o rol con privilegios
- Los triggers siempre usan `SECURITY DEFINER`
- RLS policies check `auth.uid()` para identidad
- Para admin operations: usar `supabase_service_role`

## Rollback

```sql
-- Quitar SECURITY DEFINER (potencialmente peligroso)
ALTER FUNCTION process_match_completion() SECURITY DEFINER;

-- Remover RLS (expone datos)
ALTER TABLE elo_history DISABLE ROW LEVEL SECURITY;
```
