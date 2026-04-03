# Flow: Player Profile & Statistics

Este flujo representa el centro personal del jugador, donde se visualiza su crecimiento y su historial (CU-09). Es fundamental para retener al usuario basándose en el sentido de progreso.

## User Intent: **Monitor Progression** (CU-09)
El usuario quiere ver inmediatamente cómo está su nivel (ELO) y tener pruebas de sus victorias o derrotas históricas. El diseño debe enfatizar los logros de manera visual.

## Flow Pathway

### 1. **Entry Point**
- **Trigger**: Tab `Profile` en la navegación principal o tocando el Avatar del jugador en cualquier parte de la app.
- **Screen**: `Player Profile Dashboard`.

### 2. **Main KPI Section (The Glory Board)**
- **Component**: `ELO Display Hero` ocupando el tercio superior de la pantalla.
- **Visuals**:
  - Número de ELO actual en tamaño masivo (`text-6xl`).
  - Gráfico de chispa (Sparkline) de fondo mostrando los últimos 10 matches.
  - Indicador de Δ (Delta) semanal (ej. `+14 ELO this week` en color Teal).

### 3. **Achievement Badges (Social Proof)**
- **Component**: `Badge Row` debajo del ELO.
- **Action**: Horizontal scroll de medallas obtenidas (ej: "Giant Slayer", "Tournament Winner", "Flawless Victory").
- **Interaction**: Tap en un badge abre un micro-tooltip explicando qué significa.

### 4. **Match History List**
- **Action**: Scroll vertical mirando el historial.
- **Component**: `HistoryListItem`.
  - **Data**: Fecha, Oponente, Resultado (Win/Loss), Set Scores, ELO ganado o perdido en ese match.
  - **Interaction**: Tap en un item específico abre el `Match Detail Modal` (solo lectura).

---

## Component Checklist (Top-Down)

- [ ] `ProfileLayout`: Contenedor principal, fondo oscuro, sin scroll en el hero, delegando el scroll a la lista de historia.
- [ ] `ELOGauge`: Componente visual que resalta el nivel actual del jugador usando escalas de colores según el bracket de ELO (ej. Bronze, Silver, Gold).
- [ ] `BadgeIcon`: Iconografía curada, idealmente con efectos de brillo si el logro es raro.
- [ ] `HistoryListItem`: Tarjeta condensada. Fondo verde tenue (`bg-teal-900/20`) si fue victoria, rojo tenue (`bg-red-900/20`) si fue derrota.

## Interaction Design Standards

- **Immediate Impact**: El número de ELO es la métrica reina. No debe haber desorden visual alrededor de él.
- **Gamification**: El uso de "Ranks" asociados a bandas de ELO (Ej: "Nivel 4", "Pro") debe estar codificado por colores para rápida identificación cruzada en el Home Feed.
- **History Depth**: El historial debe tener paginación infinita, pero la carga inicial lista solo los últimos 10 partidos para asegurar latencia cero de UI.
