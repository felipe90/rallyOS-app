<p align="center">
  <img src="logo.png" alt="RallyOS" width="300">
</p>

# RallyOS - Documentación

> Sistema de gestión de torneos de deportes de raqueta con arquitectura offline-first.

## Estado del Proyecto

```yaml
MVP Backend:      ✅ LISTO
Security (RLS):   ✅ Completado
Tournament Flow:   ✅ Completado
Bracket System:   ✅ Completado
ELO Calculation:   ✅ Completado
Clubs:            ✅ Completado
Community Feed:   ✅ Completado
─────────────────────────────────
Mobile App:       🔲 Pending
Payment Flow:     🔲 Post-MVP
```

## Specs MVP

```yaml
Specs:         21 creados
Use Cases:     10 verbose
Migrations:     18 aplicadas
RLS Tables:    13/15 protegidas
```

## Navegación

- [Arquitectura](architecture/README)
- [ER Diagram](architecture/ER_DIAGRAM)
- [Diagramas de Flujo](architecture/ARCHITECTURE_DIAGRAMS)
- [Schema SQL](database/schema.sql)
- [Índice de Migraciones](database/MIGRATION_INDEX)

## ADRs

- [ADR-001: ELO como Ledger](adr/001-elo-ledger)
- [ADR-002: Bracket como Linked List](adr/002-bracket-linked-list)
- [ADR-003: RLS SECURITY DEFINER](adr/003-rls-security)

## Journal

- [Development Journal](journal/DEVELOPMENT_JOURNAL)

---

*Documentación generada con [Docsify](https://docsify.js.org)*
