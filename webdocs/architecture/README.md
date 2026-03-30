# Arquitectura

Documentación de la arquitectura técnica del sistema.

## Índice

- [ER Diagram](ER_DIAGRAM) - Modelo de entidades y relaciones
- [Diagramas de Flujo](ARCHITECTURE_DIAGRAMS) - Diagramas de arquitectura
- [Secuencias](SEQUENCE_DIAGRAMS) - Diagramas de secuencia de negocio

## Stack Tecnológico

| Capa | Tecnología |
|------|------------|
| Mobile | Expo (React Native) |
| Backend | Supabase (PostgreSQL + Auth + Realtime) |
| State | TanStack Query v5 |
| Offline | AsyncStorage + SQLite |
| Styling | NativeWind (Tailwind CSS) |

## Principios

1. **Offline-First**: La app funciona sin conexión
2. **Server-Side Authority**: Toda lógica de negocio en triggers/funciones
3. **Auditoría**: ELO como ledger append-only
