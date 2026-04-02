# Flows Inventory: From Intent to Components

Este inventario documenta los 6 macro-flujos críticos de la aplicación, mapeando cada paso a las pantallas involucradas y los componentes atómicos necesarios.

## Macro-Flujo 1: **Tournament Lifecycle (Organizer)**

### **Step 1: Configuration** ([CU-01](flows/tournament-creation.md))
- **Screen**: `Tournament Creation Screen`.
- **Primary Action**: Botón `Create`.
- **Components**: `GlassForm`, `SportSelector`, `DifferentialELOToggle`, `FeeInput`.

### **Step 2: Readiness** ([CU-03](flows/attendance-check-in.md))
- **Screen**: `Attendance Check-in`.
- **Primary Action**: Toggle de llegada.
- **Components**: `PlayerCheckinCard`, `SearchFilterBar`, `AttendanceBadge`.

### **Step 3: Bracket Generation** ([CU-04](flows/bracket-management.md))
- **Screen**: `Bracket Management`.
- **Primary Action**: Botón `Generate Bracket`.
- **Components**: `GenerationControlPanel`, `WaitStateLoader` (Glassmorphism).

### **Step 4: Completion** ([CU-08](flows/tournament-results.md))
- **Screen**: `Tournament Results`.
- **Primary Action**: Botón `Close Tournament`.
- **Components**: `PodiumView`, `RewardsSummaryCard`.

---

## Macro-Flujo 2: **Competitive Journey (Player)**

### **Step 1: Discovery** ([CU-02, CU-10](flows/home-feed.md))
- **Screen**: `Home Feed` / `Discovery`.
- **Primary Action**: Seleccionar torneo.
- **Components**: `TournamentCard`, `ActivityFeedItem`, `VibeCategoryPills`.

### **Step 2: Live Scoring** ([CU-05](flows/live-scoring.md))
- **Screen**: `Live Scoreboard`.
- **Primary Action**: Cargar puntos.
- **Components**: `MassiveTapTarget`, `OptimisticScoreDisplay`, `MatchStatusBadge` (LIVE).

### **Step 3: Post-Match Feedback** ([CU-06](flows/post-match-feedback.md))
- **Screen**: `Match Result / Profile`.
- **Primary Action**: Compartir ELO.
- **Components**: `ELOUpdateSummary`, `ShareCardGenerator`, `AchievementBadge`.

---

## Macro-Flujo 3: **Desktop Expansion (Admin & Display)**

### **Step 1: Admin Management** ([PRO-01](flows-desktop/admin-desktop-layout.md))
- **Screen**: `Admin Multi-Tournament Dashboard`.
- **Primary Action**: Gestión masiva de inscripciones / Brackets.
- **Components**: `DataGridAdmin`, `BulkActionToolbar`, `QuickFilterSidebar`.

### **Step 2: Public Scoreboard** ([DIS-01](flows-desktop/tv-public-scoreboard.md))
- **Screen**: `Live Display Mode`.
- **Primary Action**: Visualización pasiva en Smart TV.
- **Components**: `LiveScoreGrid`, `CourtIndicator`, `RealtimeScoreTicker`.

---

## Atomic Components Registry (Top-Down)

| Component | Vibe Pattern | Role |
|-----------|--------------|------|
| `GlassCard` | Glassmorphism | Base container for all cards |
| `TactileButton` | Primary Check | Action confirmation |
| `ScoreBoardLarge` | High contrast | Live score entry |
| `BracketNode` | Interconnected | Bracket visualization |
| `ELOHistoryChart`| Dynamic Graphic | Player progression |
