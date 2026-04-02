# Flow: Home Feed & Discovery

Este flujo es el punto de entrada principal para el Jugador (CU-10). Permite descubrir torneos, registrarse y ver la actividad de la comunidad.

## User Intent: **Social Discovery** (CU-10, CU-02)
El usuario quiere ver "qué hay hoy" en el clubhouse. El feed debe ser dinámico, vibrante y fomentar la participación rápida.

## Flow Pathway

### 1. **Entry Point**
- **Trigger**: Apertura de la App o Tab `Home`.
- **Screen**: `Home Feed / Discovery`.

### 2. **Navigation & Filtering**
- **Action**: Filtrar por deporte o "vibe" (e.g. Competitive, Social, Rookie).
- **Component**: `VibeCategoryPills` (Horizontal scroll de etiquetas Amber/Teal).

### 3. **Tournament Discovery**
- **Action**: Scroll vertical sobre el feed de torneos activos o próximos.
- **Micro-Interaction**: Al hacer tap en la tarjeta, se expande con un `shared element transition`.
- **Component**: `TournamentCard` (Glassmorphism con indicador de estado LIVE/DRAFT).

### 4. **Quick Registration**
- **Trigger**: Botón `Register` en el detalle del torneo.
- **Interaction**: Se despliega un `Registration BottomSheet`.
- **Result**: Badge de "Inscripto" y redirección al Tab `Play`.

---

## Component Checklist (Top-Down)

- [ ] `HomeContainer`: Scrollable con gradiente sutil de fondo.
- [ ] `VibeCategoryPills`: 
    - **Branding**: Primary (Teal) para activo.
    - **Typo**: `font-medium text-sm uppercase`.
- [ ] `TournamentCard`: 
    - **Header**: Icono del deporte.
    - **Body**: Título, Fecha y Cupos disponibles.
    - **Footer**: Badge de Nivel/ELO requerido.
- [ ] `ActivityFeedItem`: Micro-reporte de "X le ganó a Y" en modo texto estilizado.

## Interaction Design Standards

- **Dynamic Feed**: El feed se actualiza con un `Pull-to-refresh` que activa una animación de Blur dinámica.
- **Glassmorphism Detail**: Las categorías (Pills) tienen un fondo `bg-white/10` que resalta sobre el color principal.
- **Tactile**: Feedback de "vibración" al completar el registro.
