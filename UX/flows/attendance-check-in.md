# Flow: Attendance & Check-in

Este flujo permite al organizador verificar qué jugadores inscriptos están físicamente presentes y listos para competir antes de generar el bracket.

## User Intent: **Readiness Check** (CU-03)
El organizador quiere una vista rápida y táctil del estado de asistencia para evitar "walkovers" por ausencia. El feedback debe ser instantáneo.

## Flow Pathway

### 1. **Entry Point**
- **Trigger**: `Organizer Dashboard` -> Tab `Attendance`.
- **Screen**: `Attendance Check-in Screen`.

### 2. **Discovery & Filtering**
- **Action**: Buscar jugador por nombre o filtrar por "Pending".
- **Component**: `SearchFilterBar` (Sticky at top).

### 3. **The Check-in Interaction**
- **Action**: Toggle en la tarjeta del jugador.
- **Micro-Interaction**: El badge `PENDING` (Gray/Quiet) cambia a `CHECKED-IN` (Teal/Solid) con una animación de `slide-fade`.
- **Component**: `PlayerCheckinCard` (Glassmorphism layer).

### 4. **Attendance Summary**
- **State**: Contador vivo de `Present / Registered` (e.g. 14 / 16).
- **Result**: Si `Present >= MinPlayers`, el botón `Generate Bracket` se habilita en el Dashboard.

---

## Component Checklist (Top-Down)

- [ ] `AttendanceContainer`: Layout scrollable con fondo Slate-900.
- [ ] `PlayerCheckinCard`: 
    - **Avatar**: Foto del jugador.
    - **Name**: Nombre legible (`text-lg font-bold`).
    - **Toggle**: Switch estilizado con feedback háptico.
- [ ] `SearchFilterBar`: Input estilizado con `bg-white/5` y `blur`.
- [ ] `ReadinessIndicator`: Barra fija inferior que muestra el progreso total de asistencia.

## Interaction Design Standards

- **Optimistic State**: El toggle cambia visualmente antes de que Supabase confirme (background sync).
- **Tactile**: Vibración corta al marcar asistencia.
- **Empty State**: Ilustración de "Nadie inscripto todavía" con CTA para editar el torneo.
