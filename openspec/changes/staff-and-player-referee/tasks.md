# Tasks: Staff & Player-As-Referee System

## Phase 1: Database Schema (Foundation)

- [x] 1.1 Crear `supabase/migrations/00000000000026_staff_enhanced.sql`:
  - Agregar ENUM `staff_status` (PENDING, ACTIVE, REJECTED, REVOKED)
  - ALTER TABLE tournament_staff: agregar status, invite_mode, invited_by, expires_at
  - Agregar índice en (tournament_id, user_id)
- [x] 1.2 Crear `supabase/migrations/00000000000027_referee_pool.sql`:
  - Crear tabla `referee_volunteers` (tournament_id, person_id, user_id, is_active)
  - Crear tabla `referee_assignments` (match_id, user_id, assigned_by, is_suggested, is_confirmed)
  - Crear vista `available_referees(match_id UUID)` con filtro de checked-in y anti-conflicto
  - Agregar UNIQUE en referee_assignments(match_id)
- [x] 1.3 Crear `supabase/migrations/00000000000028_staff_rpcs.sql`:
  - RPC `assign_staff(p_tournament_id, p_user_id, p_role, p_invite_mode)`
  - RPC `invite_staff(p_tournament_id, p_user_id, p_role)` → usa assign_staff con invite_mode=true
  - RPC `accept_invitation(p_tournament_id)` → UPDATE status PENDING→ACTIVE
  - RPC `reject_invitation(p_tournament_id)` → UPDATE status PENDING→REJECTED
  - RPC `toggle_referee_volunteer(p_tournament_id, p_is_active)`
  - RPC `generate_referee_suggestions(p_category_id)` → retorna TABLE(match_id, user_id)
  - RPC `confirm_referee_assignment(p_match_id, p_user_id)`
  - Todas con SECURITY DEFINER
- [x] 1.4 Crear `supabase/migrations/00000000000029_staff_rls_update.sql`:
  - Actualizar RLS tournament_staff: Organizer ve todo, users ven su propio
  - Actualizar RLS matches: Anyone SELECT, solo refs+organizer UPDATE
  - Actualizar RLS scores: Referee asignado puede actualizar
  - Policy para available_referees: cualquier auth.uid()
  - Policy para referee_volunteers: solo OWN
  - Policy para referee_assignments: Organizer ve todo, refs ven el suyo

## Phase 2: Seed Data (Test Dataset)

- [x] 2.1 Crear `supabase/migrations/00000000000030_seed_v2.sql`:
  - Insertar 1 sport: Padel (si no existe)
  - Insertar 1 club: "Club Pádel Medellín"
  - Crear 1 organizer user con persona y auth.users link
  - Crear 2 external referee users con persona y auth
  - Crear 16 dummy persons:
    - 8 con user_id linked (jugadores con cuenta)
    - 8 sin user_id (shadow profiles)
  - Crear 16 athlete_stats con ELOs variados:
    - 8 en rango 900-1200 (para categoría "Primera")
    - 8 en rango 600-899 (para categoría "Segunda")
  - Crear 1 tournament "Copa Pádel Medellín 2026 v2" (DRAFT)
  - Asignar organizer como ORGANIZER en tournament_staff
  - Invitar 2 referees externos (PENDING, auto-aceptarlos en seed)

## Phase 3: Testing & Verification

- [x] 3.1 Tests de RLS:
  - ✅ Verificar que organizer puede gestionar staff
  - ✅ Verificar que no-staff no puede ver tournament_staff
  - ✅ Verificar que shadow profiles no aparecen en available_referees
  - ✅ Verificar que jugador no puede ser referee de su propio match
- [x] 3.2 Tests de Flujo de Staff:
  - ✅ assign_staff → status ACTIVE (con auth check correcto)
  - ✅ invite_staff → status PENDING
  - ✅ accept_invitation RPC existe
  - ✅ toggle_referee_volunteer RPC existe
- [x] 3.3 Tests de Player-As-Referee:
  - ✅ referee_volunteers table lista
  - ✅ available_referees view con 8 columnas correctas
  - ✅ generate_referee_suggestions RPC existe con round-robin
  - ✅ referee_assignments tiene schema correcto
- [x] 3.4 Tests de E2E (CU-18):
  - ✅ Copa Padel v1: 4 entries, 3 matches (LIVE)
  - ✅ Copa Padel v2: 2 categorias, 16 entries (DRAFT)
  - ✅ Round Robin: Grupo A con 4 miembros, 6 matches generados
  - ✅ Seed data: 23 persons, 23 stats, 20 entries

## Phase 4: Cleanup & Documentation

- [x] 4.1 Actualizar `DEVELOPMENT_JOURNEY.md` con Day 4
- [x] 4.2 Actualizar modelo de dominio en `webdocs/database/schema.md`
- [x] 4.3 Actualizar diagramas en `webdocs/architecture/ER_DIAGRAM.md` y `ARCHITECTURE_DIAGRAMS.md`
- [x] 4.4 Verificar que seed.sql original sigue funcional (backward compatibility)
  - ✅ Copa Padel v1 intacta: 4 entries, 3 matches
  - ✅ Copa Padel v2 intacta: 2 categorias, 16 entries
  - ✅ Players: 11 con auth + 12 shadow profiles
