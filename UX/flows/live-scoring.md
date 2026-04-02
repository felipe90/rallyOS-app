# Flow: Live Scoring

Este flujo representa el corazón competitivo de RallyOS: la carga de puntos en tiempo real durante un partido.

## User Intent: **Live Match Tracker** (CU-05)
El usuario (jugador o referee) necesita registrar el progreso del match con el menor número de taps posible y máxima legibilidad.

## Flow Pathway

### 1. **Entry Point**
- **Trigger**: Tab `Play` (Active Match List) -> Seleccionar Match `LIVE`.
- **Screen**: `Match Detail / Live Scoreboard`.

### 2. **Scoring Interaction**
- **Action**: Tap en el área del Jugador A o B.
- **Micro-Interaction**: `+1` aparece con una animación de `scale`.
- **Component**: `MassiveTapTarget` (Ocupa el 50% de la pantalla por jugador).

### 3. **Validation & Sync**
- **State**: `Optimistic Update` local instantáneo.
- **Feedback**: Vibración corta (Haptic Feedback).
- **Background**: Sync con `Supabase` (Match Status & Score table).

### 4. **Match Conclusion**
- **Trigger**: Win condition alcanzada (e.g. 21 puntos).
- **Result**: Modal de `Match Finished`.
- **Component**: `ELOUpdateSummary`.

---

## Component Checklist (Top-Down)

- [ ] `MatchContainer`: Layout base con Glassmorphism.
- [ ] `ScoreDisplay`: Texto gigante (`text-6xl`) para legibilidad.
- [ ] `PlayerActionZone`: Área táctil de gran formato.
- [ ] `UndoButton`: Acción rápida para corregir errores de dedo.
- [ ] `HapticFeedback`: Trigger táctil al anotar.
