# Design: UX Blueprint & Interaction Map

Este documento mapea la lógica funcional de los CU-01 a CU-10 a una experiencia de usuario (UX) coherente, siguiendo los principios de **High-Tech Clubhouse** y **Glassmorphism**.

## Information Architecture (IA)

### Navigation Strategy: **Tab-Based Navigation**
Priorizamos la accesibilidad con una barra inferior de navegación (Bottom Tab Bar) para las acciones más frecuentes.

1.  **Home (Activity Feed)**: El pulso de la comunidad.
2.  **Discovery**: Búsqueda coordinada de torneos y clubes.
3.  **Play (Active Match)**: Botón central destacado para acceso rápido a la carga de scores.
4.  **Tournaments**: Gestión de los torneos donde el usuario es jugador u organizador.
5.  **Profile**: Estadísticas de ELO, historial y "Achievement Room".

---

## Screen Inventory

### 1. **Home & Social**
- `[Feed Screen]`: (CU-10) Listado dinámico de matches finalizados, registros y anuncios de torneos.
- `[Match Share Card]`: (CU-10) Imagen generada dinámicamente para compartir resultados en redes sociales.

### 2. **Registration & Discovery**
- `[Discovery Screen]`: (CU-02) Lista de torneos próximos con filtros por deporte y nivel de ELO.
- `[Tournament Detail]`: (CU-02) Vista detallada (Reglas, Fees, Participantes).
- `[Registration Modal]`: (CU-02) Formulario de pago y confirmación de entry status.

### 3. **Tournament Management (Organizer Only)**
- `[Organizer Dashboard]`: (CU-01, CU-03, CU-04, CU-08) Centro de control del torneo.
- `[Tournament Creation Form]`: (CU-01) Formulario paso a paso para configurar el torneo.
- `[Attendance/Check-in]`: (CU-03) Lista de jugadores con toggle de asistencia (Offline-Ready).
- `[Bracket Management]`: (CU-04, CU-07) Control de generación de brackets y estado de avance.
- `[Tournament Closure View]`: (CU-08) Pantalla final de resultados y cierre oficial.

### 4. **Live Competition & Brackets**
- `[Bracket Canvas]`: (CU-04, CU-07) Visualización de brackets estilo "Infinite Canvas" con scroll y zoom.
- `[Match List]`: (CU-05) Lista de partidos pendientes/en vivo para selección rápida.
- `[Live Scoreboard]`: (CU-05) Pantalla táctil de carga de puntos (Min taps, Max legibility).

### 5. **Player Profile & ELO**
- `[User Profile]`: (CU-09) Dashboard personal.
- `[ELO History Chart]`: (CU-06, CU-09) Gráfico interactivo de evolución de rating.
- `[Achievements/Badges]`: (CU-09) Visualización de logros obtenidos.

### 6. **Desktop & Public Display (Expansion)**
- `[Admin Desktop Dashboard]`: (PRO-01) Vista de alta densidad para gestión masiva.
- `[TV Scoreboard Display]`: (DIS-01) Dashboard público con actualización por Realtime.

---

## Interaction Flows

### Flow A: **The Tournament Journey (Player)**
`Discovery` → `Tournament Detail` → `Registration Modal` → `Confirmation Feed` → `Live Scoreboard` → `Post-Match ELO Feedback`.

### Flow B: **The Tournament Setup (Organizer)**
`Organizer Dashboard` → `Creation Form` → `Attendance Management` → `Bracket Generation` → `Live Monitoring` → `Tournament Closure`.

### Flow C: **The Desktop & Display Extension**
`Admin Desktop Dash` → `Management Tab` → `Live TV Link` → `Public TV Mode`.

---

## Technical UX Standards
- **Optimistic UI**: Todas las interacciones de score deben reflejarse localmente de inmediato (Zustand/TanStack).
- **Realtime Sync**: La vista de TV (Display) usa **Supabase Realtime** para actualizaciones pasivas.
- **Glassmorphism Overlay**: Los modales y paneles laterales usan desenfoque de fondo (`blur`).
- **Tactile Transitions**: Uso de `React Native Reanimated` para transiciones suaves entre estados de torneo.
- **Outdoor-First**: Tipografía de alto contraste y targets táctiles de gran formato (min 48dp).

