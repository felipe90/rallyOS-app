# Modelo RLS

Row Level Security - Políticas de acceso por fila.

## Concepto

Supabase usa RLS para controlar qué datos puede ver/modificar cada usuario según su identidad (`auth.uid()`).

## Security DEFINER

Los triggers usan `SECURITY DEFINER` para bypasear RLS cuando necesitan escribir a tablas protegidas.

## Modelo de Seguridad

```yaml
Tabla:              SELECT:    INSERT:         UPDATE:
elo_history:        Todos,    Bloqueado,     Bloqueado  (Trigger only)
scores:            Todos,    Solo referee,  Solo referee  (Trigger)
matches:            Staff,    Yes,           Staff       (Trigger)
athlete_stats:     Todos,    Bloqueado,     Bloqueado   (Trigger)
tournament_entries: Todos,   Yes,           Owner/Org   (Trigger)
```
