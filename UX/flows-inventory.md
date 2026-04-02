# Flows Inventory: From Intent to Components

Este inventario documenta los 6 macro-flujos críticos de la aplicación, mapeando cada paso a las pantallas involucradas y los componentes atómicos necesarios.

## Macro-Flujo 1: **Tournament Lifecycle (Organizer)**

### **Step 1: Configuration** (CU-01)
- **Screen**: `Tournament Creation Screen`.
- **Primary Action**: Botón `Create`.
- **Components**: `GlassForm`, `SportSelector`, `DifferentialELOToggle`, `FeeInput`.

### **Step 2: Readiness** (CU-03)
- **Screen**: `Attendance Check-in`.
- **Primary Action**: Toggle de llegada.
- **Components**: `PlayerCheckinCard`, `SearchFilterBar`, `AttendanceBadge`.

### **Step 3: Bracket Generation** (CU-04)
- **Screen**: `Bracket Management`.
- **Primary Action**: Botón `Generate Bracket`.
- **Components**: `GenerationControlPanel`, `WaitStateLoader` (Glassmorphism).

### **Step 4: Completion** (CU-08)
- **Screen**: `Tournament Results`.
- **Primary Action**: Botón `Close Tournament`.
- **Components**: `PodiumView`, `RewardsSummaryCard`.

---

## Macro-Flujo 2: **Competitive Journey (Player)**

### **Step 1: Discovery** (CU-02, CU-10)
- **Screen**: `Home Feed` / `Discovery`.
- **Primary Action**: Seleccionar torneo.
- **Components**: `TournamentCard`, `ActivityFeedItem`, `VibeCategoryPills`.

### **Step 2: Live Scoring** (CU-05)
- **Screen**: `Live Scoreboard`.
- **Primary Action**: Cargar puntos.
- **Components**: `MassiveTapTarget`, `OptimisticScoreDisplay`, `MatchStatusBadge` (LIVE).

### **Step 3: Post-Match Feedback** (CU-06)
- **Screen**: `Match Result / Profile`.
- **Primary Action**: Compartir ELO.
- **Components**: `ELOUpdateSummary`, `ShareCardGenerator`, `AchievementBadge`.

---

## Atomic Components Registry (Top-Down)

| Component | Vibe Pattern | Role |
|-----------|--------------|------|
| `GlassCard` | Glassmorphism | Base container for all cards |
| `TactileButton` | Primary Check | Action confirmation |
| `ScoreBoardLarge` | High contrast | Live score entry |
| `BracketNode` | Interconnected | Bracket visualization |
| `ELOHistoryChart`| Dynamic Graphic | Player progression |
