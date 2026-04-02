# Flow: Tournament Results & Closure

Este flujo marca el fin del torneo (CU-08). Proporciona el cierre competitivo y la visualización de los ganadores (PODIUM).

## User Intent: **Celebration & Finalization** (CU-08)
El organizador quiere cerrar formalmente el torneo, validando que todos los resultados sean correctos y celebrando a los ganadores (Vibe: Solid/Checkmark).

## Flow Pathway

### 1. **Entry Point**
- **Trigger**: `Organizer Dashboard` -> Botón `Finalize Tournament`.
- **Screen**: `Verification Summary`.

### 2. **Verification & Summary**
- **Action**: Revisar listado de ganadores por categoría.
- **Component**: `ResultsVerificationList` (Muestra nombre, score y ELO Δ).

### 3. **The Closure (The Moment of Truth)**
- **Action**: Tap en el botón `Confirm Closure`.
- **Micro-Interaction**: Animación de confeti sutil (Teal-Primary) y cambio de estado a `FINISHED`.
- **Component**: `TactileButton` (Confirmación final).

### 4. **Podium View**
- **Result**: Visualización del Podium (1ero, 2do, 3ero).
- **Component**: `PodiumView` (Glassmorphism con gradientes de oro/plata/bronce).

---

## Component Checklist (Top-Down)

- [ ] `PodiumView`: 
    - **Avatar**: Con corona de laurel estilizada.
    - **ELO Change**: Badge flotante con el incremento total del torneo.
- [ ] `RewardsSummaryCard`: Si hay premios (Fees), muestra el desglose del pozo.
- [ ] `HistoryEntry`: Entrada final en el `activity_feed`.

## Interaction Design Standards

- **Celebration Vibe**: Transición de pantalla completa de fondo Slate-900 a un resplandor Teal suave al finalizar.
- **Solid**: El estado `FINISHED` en el Dashboard debe ser inmutable y visualmente "tranquilo".
- **Achievement Badge**: Se dispara un trigger para que los jugadores ganadores vean una notificación especial en su perfil.
