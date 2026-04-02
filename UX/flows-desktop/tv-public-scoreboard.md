# Flow: Public TV Scoreboard

Este flujo define la experiencia de visualización para TVs y pantallas gigantes en clubes. Optimizado para lectura a distancia (5-10m) y sin interacción de usuario.

## User Intent: **Spectator Live Hub**
Público, jugadores y acompañantes quieren ver quién está jugando, en qué cancha y cuál es el score actual de forma instantánea y emocionante.

## TV Display Architecture

### 1. **High-Contrast Grid** (1920x1080 / 4K)
- **Component**: `LiveScoreGrid`.
- **Layout**: Máximo 4-6 matches por pantalla (o rotación automática).
- **Branding**: Fondo Slate-950 con acentos en Teal (`Primary`) y Amber (`Live`).

### 2. **Realtime Heartbeat**
- **Action**: Suscripción automática a `Supabase Realtime` para la tabla `matches` del torneo específico.
- **Update**: El score "late" (pulsa) cuando se recibe un cambio de puntos. Escala por milisegundos (`scale-110`) para llamar la atención.

### 3. **The Score Node** (Component Detail)
- **Structure**:
    - **Cancha/Court**: Identificador superior (`text-lg font-black uppercase text-amber-500`).
    - **Jugadores**: Nombres grandes (`text-3xl font-bold`).
    - **Scores**: Dígitos masivos (`text-6xl font-black bg-white/5 rounded-xl padding-4`).

---

## Flow Pathway (Passive)

### 1. **Launch Sequence**
- **Trigger**: Organizador abre la URL pública `/display/:tournament_id` en una Smart TV o PC conectada.
- **Action**: Splash Screen de "RALLYOS LIVE" con el logo del club y el nombre del torneo.
- **State**: Conexión a Realtime establecida.

### 2. **Auto-Rotation (If many matches)**
- **Action**: Si hay > 6 matches activos, la pantalla rota automáticamente cada 15 segundos entre grupos de matches.
- **Visual**: Transición de `fade-through` suave.

### 3. **Match Finished Celebration**
- **Trigger**: Match Status -> FINISHED.
- **Visual**: El nodo del match resalta con un borde Teal grueso y el ganador se muestra con un icono de corona por 10 segundos antes de desaparecer del grid de "en vivo".

---

## Technical Constraints (MVP)

- **Auth**: **PUBLIC**. No requiere inicio de sesión (RLS Solo-Lectura).
- **Responsive**: Optimizado para `aspect-ratio: 16/9`.
- **Typo**: Usar fuentes sans-serif de alto peso (`font-black`) para legibilidad máxima a la distancia.
- **Data**: Solo muestra matches en estado `LIVE` o registrados en los últimos 30 segundos.
