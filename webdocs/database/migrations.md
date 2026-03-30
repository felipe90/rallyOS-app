# Índice de Migraciones

Estado: **2026-03-30**

## Resumen

| Total | Completadas | Pendientes |
|-------|-------------|------------|
| 7 | 7 | 0 |

## Mapa de Migraciones

| # | Archivo | Feature | Estado | Rollback |
|---|---------|---------|--------|----------|
| 00 | `init_schema.sql` | Core Schema | ✅ | ❌ |
| 01 | `security_policies.sql` | Security | ✅ | ✅ |
| 02 | `add_elo_history.sql` | ELO Ledger | ✅ | ✅ |
| 03 | `add_entry_status.sql` | Payment State | ✅ | ✅ |
| 04 | `fix_offline_sync_trigger.sql` | Sync Security | ✅ | ✅ |
| 05 | `implement_elo_calculation.sql` | ELO Calc | ✅ | ✅ |
| 06 | `bracket_advancement.sql` | Brackets | ✅ | ✅ |

## Comandos

```bash
# Ver migraciones aplicadas
psql ... -c "SELECT * FROM supabase_migrations.schema_migrations ORDER BY version;"

# Reset completo
supabase db reset

# Ver triggers
psql ... -c "SELECT tgname, tablename FROM pg_trigger WHERE tgname NOT LIKE 'pg_%';"

# Ver RLS policies
psql ... -c "SELECT tablename, policyname, cmd FROM pg_policies;"
```

## Referencias ADR

| Decisión | ADR |
|----------|-----|
| ELO como ledger | [ADR-001](../adr/001-elo-ledger) |
| Bracket como linked list | [ADR-002](../adr/002-bracket-linked-list) |
| RLS con SECURITY DEFINER | [ADR-003](../adr/003-rls-security) |
