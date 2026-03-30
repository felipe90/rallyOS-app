# Modelo RLS

Row Level Security - Políticas de acceso por fila.

## Concepto

Supabase usa RLS para controlar qué datos puede ver/modificar cada usuario según su identidad (`auth.uid()`).

## Security DEFINER

Los triggers usan `SECURITY DEFINER` para bypasear RLS cuando necesitan escribir a tablas protegidas.

## Modelo de Seguridad

| Tabla | Client SELECT | Client INSERT | Client UPDATE | Trigger |
|-------|--------------|---------------|--------------|---------|
| `elo_history` | ✅ Todos | ❌ Bloqueado | ❌ Bloqueado | ✅ |
| `scores` | ✅ Todos | ✅ Solo referee | ✅ Solo referee | ✅ |
| `matches` | ✅ Staff | ✅ | ✅ Staff | ✅ |
| `athlete_stats` | ✅ Todos | ❌ | ❌ | ✅ |
| `tournament_entries` | ✅ | ✅ | ✅ Owner/Org | ✅ |
