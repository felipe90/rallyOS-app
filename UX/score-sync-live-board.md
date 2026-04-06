# 🚧 POC: Score Sync Live Board

> **Estado**: POC (Proof of Concept)  
> **Versión**: 0.2.0  
> **Última actualización**: 2026-04-06  
> **Objetivo**: Probar en torneo semanal — validar la experiencia P2P entre referee y jugadores

---

## 1. Concept & Vision

**Score Sync Live Board** es un sistema de scoring en tiempo real que elimina la fricción entre el referee y los jugadores. El teléfono del referee se convierte en el único punto de entrada de datos y transmite el estado del match a todos los jugadores conectados instantáneamente.

**核心价值 (Core Value)**: 
> "Una sola acción, máximo impacto"

- El referee marca UNA VEZ
- Todos ven el score en tiempo real
- Zero internet requerido
- Funciona en el venue más remote

---

## 2. User Flows

### 2.1 Flow Principal: Crear Session

```
[Jugador/Referee] → [Crear Session] → [Compartir Código/QR] → [Esperar Conexiones] → [Iniciar Match]
```

### 2.2 Flow Principal: Unirse a Session

```
[Jugador] → [Unirse con Código] → [Ver Waiting Room] → [Scoreboard Live]
```

### 2.3 Flow Principal: Marcar Punto

```
[Referee] → [Tap Jugador] → [+1 Point] → [Regla valida] → [Broadcast] → [Todos actualizan]
```

### 2.4 Flow Principal: Set Completo

```
[Punto] → [Valida 11 pts?] → [Sí] → [Sumar set] → [Valida best-of?] → [Sí] → [Match completo] → [Mostrar winner]
```

---

## 3. Screens

### 3.1 Screen: Home / Entry Point

**Trigger**: App abierta, sin sesión activa

**Elementos**:
- Logo RallyOS
- Título: "Score Sync"
- Subtítulo: "Scoring en tiempo real, sin internet"
- Botón Principal: "Crear Session" (Referee)
- Botón Secundario: "Unirse con Código"
- Nota al pie: "No requiere cuenta"

**Estado Visual**:
```
┌─────────────────────────────┐
│                             │
│         [RallyOS Logo]      │
│                             │
│        ⚡ Score Sync         │
│    Scoring en tiempo real    │
│       sin internet          │
│                             │
│  ┌─────────────────────┐   │
│  │   + Crear Session    │   │
│  │   (Soy Referee)      │   │
│  └─────────────────────┘   │
│                             │
│    ¿Tienes un código?       │
│    ┌─────────────────────┐  │
│    │   Unirse con Código │  │
│    └─────────────────────┘  │
│                             │
│   ⚠ No requiere cuenta     │
└─────────────────────────────┘
```

---

### 3.2 Screen: Create Session (Referee View)

**Trigger**: Tap en "Crear Session"

**Elementos**:
- Código de sesión (6 dígitos): `PADEL-4821`
- QR Code generado automáticamente
- Lista de jugadores conectados (en espera)
- Botón "Iniciar Match" (habilitado cuando hay ≥2 conectados)
- Botón "Cancelar"

**Estado Visual**:
```
┌─────────────────────────────┐
│  ← Volver                    │
│                             │
│  Session Creada             │
│  Código: PADEL-4821         │
│                             │
│  ┌─────────────────────┐   │
│  │   [QR CODE]         │   │
│  │   Escanear para     │   │
│  │   unirse             │   │
│  └─────────────────────┘   │
│                             │
│  O compartir código:         │
│  ┌─────────────────────┐   │
│  │ P A D E L - 4 8 2 1 │   │
│  │      [Copiar]        │   │
│  └─────────────────────┘   │
│                             │
│  ─────────────────────────  │
│  Jugadores (0/4)            │
│  [Esperando...]             │
│                             │
│  ┌─────────────────────┐   │
│  │  🔒 Iniciar Match    │   │
│  │  (Requiere 2 min)   │   │
│  └─────────────────────┘   │
└─────────────────────────────┘
```

---

### 3.3 Screen: Join Session (Player View)

**Trigger**: Tap en "Unirse con Código"

**Elementos**:
- Input de 6 dígitos
- Teclado numérico custom (no keyboard nativo)
- Botón "Unirse"
- Estados: Idle → Loading → Success/Error

**Estado Visual**:
```
┌─────────────────────────────┐
│  ← Volver                    │
│                             │
│  Unirse a Session           │
│                             │
│  Ingresá el código          │
│  de 6 dígitos:              │
│                             │
│  ┌───┬───┬───┬───┬───┬───┐  │
│  │   │   │   │   │   │   │  │
│  └───┴───┴───┴───┴───┴───┘  │
│                             │
│  [1] [2] [3]                │
│  [4] [5] [6]                │
│  [7] [8] [9]                │
│  [⌫] [0] [→]                │
│                             │
│  ┌─────────────────────┐   │
│  │      Unirse          │   │
│  └─────────────────────┘   │
└─────────────────────────────┘
```

---

### 3.4 Screen: Live Scoreboard (Referee Mode)

**Trigger**: Match iniciado, rol=referee

**Elementos**:
- Score principal: Sets y Games
- Botones táctiles para cada jugador: [+1] [-1]
- Indicador de quién tiene el servicio
- Indicador de conexiones activas
- Botón "Finalizar Match"

**Estado Visual**:
```
┌─────────────────────────────┐
│  PADEL-4821  ●●● 3 conex.   │
├─────────────────────────────┤
│                             │
│       ⬆️ JUGADOR A          │
│         Miguel              │
│         ★ Servicio          │
│                             │
│       SET   GAME   PTS      │
│       ─────────────────     │
│         2      4     12     │
│                             │
│   ┌──────────┐ ┌──────────┐│
│   │          │ │          ││
│   │    -1    │ │   +1     ││
│   │  (error) │ │  (punto) ││
│   │          │ │          ││
│   └──────────┘ └──────────┘│
│                             │
├─────────────────────────────┤
│   ┌──────────┐ ┌──────────┐│
│   │          │ │          ││
│   │    -1    │ │   +1     ││
│   │  (error) │ │  (punto) ││
│   │          │ │          ││
│   └──────────┘ └──────────┘│
│                             │
│       SET   GAME   PTS      │
│       ─────────────────     │
│         1      3      8     │
│                             │
│       ⬇️ JUGADOR B           │
│         Pablo               │
│                             │
├─────────────────────────────┤
│         [🏁 Fin Match]      │
└─────────────────────────────┘
```

**Interactions**:
- **Tap +1**: Incrementa punto para ese jugador
- **Tap -1**: Decrementa punto (corrige error humano)
- **Long press +1**: Cambio rápido (para puntos consecutivos)
- **-1 disabled** cuando puntos = 0

---

### 3.5 Screen: Live Scoreboard (Viewer Mode)

**Trigger**: Match iniciado, rol=viewer

**Elementos**:
- Score principal (SOLO LECTURA)
- Indicador "Solo espectador"
- Sin botones de scoring
- Indicador de conexión
- Timer de último update

**Estado Visual**:
```
┌─────────────────────────────┐
│  ● Conectado      hace 2s   │
├─────────────────────────────┤
│                             │
│       ⬆️ JUGADOR A          │
│         Miguel              │
│                             │
│       SET   GAME   PTS      │
│       ─────────────────     │
│         2      4     12     │
│                             │
├─────────────────────────────┤
│                             │
│  ░░░░░░░░░░░░░░░░░░░░░░░░  │
│  ░░░░░░░░░░░░░░░░░░░░░░░░  │
│  ░░  SOLO LECTURA  ░░░░░░  │
│  ░░░░░░░░░░░░░░░░░░░░░░░░  │
│  ░░░░░░░░░░░░░░░░░░░░░░░░  │
│                             │
├─────────────────────────────┤
│       SET   GAME   PTS      │
│       ─────────────────     │
│         1      3      8     │
│                             │
│       ⬇️ JUGADOR B           │
│         Pablo               │
│                             │
├─────────────────────────────┤
│         El Pro vs El Rayo   │
└─────────────────────────────┘
```

---

### 3.6 Screen: Match Setup (Referee Config)

**Trigger**: Tap en "Iniciar Match" después de crear sesión

**Elementos**:
- Nombre Jugador A (input manual o selección)
- Nombre Jugador B (input manual o selección)
- Selector de formato: "Al mejor de 3" / "Al mejor de 5"
- Selector de puntos por set: 11 / 15 / 21
- Indicador de servicio inicial (quien empieza)
- Botón "Comenzar"

**Estado Visual**:
```
┌─────────────────────────────┐
│  ← Volver                    │
│                             │
│  Configurar Match           │
│                             │
│  ─────────────────────────  │
│                             │
│  Jugador A                  │
│  ┌─────────────────────┐   │
│  │ Miguel              │   │
│  └─────────────────────┘   │
│  ○ Servicio                │
│                             │
│  Jugador B                  │
│  ┌─────────────────────┐   │
│  │ Pablo               │   │
│  └─────────────────────┘   │
│  ○ Servicio                │
│                             │
│  ─────────────────────────  │
│  Formato                    │
│  ┌───────────┐ ┌───────────┐│
│  │  2 de 3  │→│  3 de 5  │ │
│  └───────────┘ └───────────┘│
│                             │
│  Puntos por set              │
│  ┌───────────┐ ┌───────────┐│
│  │   11 pts  │ │   15 pts  │ │
│  └───────────┘ └───────────┘│
│                             │
│  ─────────────────────────  │
│                             │
│  ┌─────────────────────┐   │
│  │    Comenzar Match     │   │
│  └─────────────────────┘   │
└─────────────────────────────┘
```

---

### 3.7 Screen: Set Won (Animation Overlay)

**Trigger**: Cuando un jugador gana un set

**Elementos**:
- Overlay semi-transparente
- Mensaje: "¡SET PARA [NOMBRE]!"
- Score del set recién completado
- Auto-dismiss después de 3 segundos
- También aparece en viewers

**Estado Visual**:
```
┌─────────────────────────────┐
│█████████████████████████████│
│█████████████████████████████│
│████                     ████│
│████                     ████│
│████   ¡SET PARA MIGUEL! ████│
│████                     ████│
│████    11 - 7           ████│
│████                     ████│
│████  Sets: Miguel 2-1   ████│
│████                     ████│
│█████████████████████████████│
│█████████████████████████████│
└─────────────────────────────┘
```

---

### 3.8 Screen: Match Won (Final Overlay)

**Trigger**: Cuando un jugador gana el match

**Elementos**:
- Overlay full-screen con confetti animation
- Mensaje: "¡[NOMBRE] GANA EL MATCH!"
- Score final completo
- Botón "Ver Resumen"
- Botón "Nuevo Match" (reinicia con mismos jugadores)

**Estado Visual**:
```
┌─────────────────────────────┐
│                             │
│        🎉 ¡FELICIDADES! 🎉  │
│                             │
│       MIGUEL GANA EL        │
│          MATCH!             │
│                             │
│       Sets: 3-1            │
│  ┌─────────────────────┐   │
│  │   Miguel    Pablo   │   │
│  │      11  -   6      │   │
│  │      11  -   9      │   │
│  │       9  -  11      │   │
│  │      11  -   8      │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │    Ver Resumen       │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │     Nuevo Match      │   │
│  └─────────────────────┘   │
└─────────────────────────────┘
```

---

## 4. Scoring Rules Engine

### 4.1 Sport: Table Tennis (Teni de Mesa)

| Config | Valor |
|--------|-------|
| Puntos por set | 11 (con 2 de diferencia mínimo) |
| Best of | 3 o 5 sets |
| Deuce | Se juega hasta +2 desde 10-10 |
| Servicio | Cada 2 puntos (alternando) |

### 4.2 Scenarios

#### Scenario 1: Punto normal
```
Jugador marca punto antes de 10-10
→ Punto incrementado
→ Si puntos < 11, continuar set
→ Si puntos = 11 Y diferencia ≥ 2, set para ese jugador
```

#### Scenario 2: Deuce
```
Jugador marca punto cuando score = 10-10
→ Punto incrementado
→ Si diferencia = 2, set para ese jugador
→ Si diferencia = 1, continuar (sigue deuce)
```

#### Scenario 3: Cambio de servicio
```
Jugador marca punto Y (puntosA + puntosB) % 2 === 0
→ Cambiar servicio al otro jugador
→ (Servicio alterna cada 2 puntos)
```

#### Scenario 4: Cambio de lado
```
Al terminar cada set
→ Jugadores cambian de lado de la mesa
→ Servicio inicial: quien perdió el set anterior inicia
```

#### Scenario 5: Corrección de punto (Error humano)
```
Referee toca -1 para jugador A
→ Decrementar puntos de A en 1
→ Si puntosA < 0, no hacer nada (ya está en 0)
→ Si servicio estaba con A Y (puntosA + puntosB) era impar antes del decremento
   → Restaurar servicio a A
→ Broadcast actualización a todos
→ Registrar en history como "CORRECTION"
```

#### Scenario 6: Reversión de set ganado
```
Si referee decrementa puntos Y el set ya estaba ganado (11+ pts con diferencia)
→ Permitir decremento sin validar
→ El set queda "en juego" hasta que se alcance nuevamente 11+2 diferencia
→ Broadcast "SET EN JUEGO"
```

#### Scenario 7: Deshacer múltiples puntos
```
Referee toca "Historia" button
→ Muestra últimos 5 puntos marcados
→ Referee puede seleccionar cuál deshacer
→ Aplica las reglas de decremento inversamente
```

### 4.3 Data Model

```typescript
interface ScoringConfig {
  format: 'BEST_OF_3' | 'BEST_OF_5';
  pointsPerSet: 11 | 15 | 21;
  minDifference: 2;
}

interface SetScore {
  a: number;
  b: number;
}

type PointAction = 'POINT_A' | 'POINT_B' | 'CORRECTION_A' | 'CORRECTION_B';

interface ScoreChange {
  id: string;                    // UUID único
  action: PointAction;          // Tipo de acción
  timestamp: number;             // Unix timestamp
  pointBefore: SetScore;         // Score antes del cambio
  pointAfter: SetScore;          // Score después del cambio
  setWon: boolean;               // Si esta acción ganó un set
  matchWon: boolean;             // Si esta acción ganó el match
  correctedBy?: string;           // ID de la corrección que revirtió esta acción
}

interface MatchState {
  sessionId: string;
  players: {
    a: { name: string; };
    b: { name: string; };
  };
  scoring: ScoringConfig;
  score: {
    sets: SetScore;           // Sets ganados: { a: 2, b: 1 }
    currentSet: SetScore;     // Puntos en set actual: { a: 8, b: 6 }
    serving: 'A' | 'B';
  };
  setHistory: SetScore[];     // Historial de sets: [{a: 11, b: 7}, {a: 9, b: 11}]
  history: ScoreChange[];      // Últimos 10 cambios (para undo)
  status: 'CONFIG' | 'LIVE' | 'FINISHED';
  winner: 'A' | 'B' | null;
}
```

### 4.4 State Transitions

```
CONFIG → LIVE (cuando referee inicia match)
LIVE → LIVE (en cada punto)
LIVE → LIVE (al ganar set, resetea currentSet)
LIVE → FINISHED (al ganar match)
FINISHED → CONFIG (nuevo match, mismos jugadores)
```

---

## 5. Component Inventory

### 5.1 Core Components

| Componente | Descripción | Estados |
|------------|-------------|---------|
| `SessionCodeInput` | Input de 6 dígitos custom | idle, focused, error, success |
| `QRCodeDisplay` | Generador de QR | loading, ready |
| `ConnectionIndicator` | Shows P2P status | connected (green), reconnecting (yellow), disconnected (red) |
| `ScoreDisplay` | Display gigante de score | normal, point-added (animation), winner (celebration) |
| `ScoreButton` | Botón +/- para cada jugador | idle, pressed, disabled (no -1 when 0) |
| `ScoreButtonGroup` | Grupo de botones [+1][-1] por jugador | normal, disabled |
| `HistoryDrawer` | Drawer con últimos puntos | collapsed, expanded |
| `HistoryItem` | Item individual en historial | point, correction, undo-available |
| `EndMatchButton` | Finalizar match | idle, confirm-modal |
| `WaitingRoomList` | Lista de conectados | empty, populated |
| `ServiceIndicator` | Muestra quién tiene el servicio | playerA, playerB |
| `SetWonOverlay` | Animación de set ganado | hidden, animating, dismissing |
| `MatchWonOverlay` | Animación de match ganado | hidden, animating, dismissing |

### 5.2 Design Tokens

```typescript
const ScoreSyncTokens = {
  colors: {
    refereeZone: '#14B8A6',    // Teal primary
    playerAZone: '#3B82F6',    // Blue
    playerBZone: '#EF4444',    // Red
    scoreText: '#F8FAFC',      // White
    background: '#0F172A',     // Slate dark
    surface: '#1E293B',        // Slate light
    connected: '#22C55E',     // Green
    reconnecting: '#F59E0B',   // Amber
    disconnected: '#EF4444',   // Red
  },
  spacing: {
    tapZoneMinHeight: '50%',
    buttonMinHeight: '48px',
  },
  typography: {
    scoreSize: 'text-8xl',
    setGameSize: 'text-4xl',
  }
}
```

---

## 5. Technical Approach (P2P Architecture)

### 5.1 Stack

```
┌─────────────────────────────────────────────┐
│                 React Native                 │
│                 (Expo)                      │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────┐     ┌─────────────────┐   │
│  │  expo-nearby │     │  expo-local-info │   │
│  │  (Bluetooth) │     │  (Device Name)   │   │
│  └─────────────┘     └─────────────────┘   │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  Custom P2P Server (Node.js/WS)     │   │
│  │  - Create session                    │   │
│  │  - Broadcast state                   │   │
│  │  - Handle reconnection               │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  ┌─────────────┐     ┌─────────────────┐   │
│  │  react-native │     │  react-native-qr │   │
│  │  -scanner    │     │  -generator      │   │
│  └─────────────┘     └─────────────────┘   │
│                                             │
└─────────────────────────────────────────────┘
```

### 5.2 Protocolo de Comunicación

**WebSocket Messages**:

```typescript
// Host → Client: State Update
interface StateUpdate {
  type: 'STATE_UPDATE';
  payload: {
    sessionId: string;
    matchState: MatchState;
    timestamp: number;
  };
}

// Client → Host: Request State
interface StateRequest {
  type: 'STATE_REQUEST';
  payload: {
    sessionId: string;
  };
}

// Host → Client: Player Joined
interface PlayerJoined {
  type: 'PLAYER_JOINED';
  payload: {
    playerName: string;
    playerCount: number;
  };
}

// Host → Client: Match Ended
interface MatchEnded {
  type: 'MATCH_ENDED';
  payload: {
    winner: 'A' | 'B';
    finalScore: Score;
  };
}
```

**MatchState**:
```typescript
interface MatchState {
  sessionId: string;
  playerA: { name: string; };
  playerB: { name: string; };
  score: {
    sets: { a: number; b: number };
    games: { a: number; b: number };
    points: { a: number; b: number };
    serving: 'A' | 'B';
  };
  status: 'WAITING' | 'LIVE' | 'FINISHED';
  createdAt: number;
}
```

### 5.3 Discovery Mechanism

**Opción A: QR Code (P0 - MVP)**
- Referee genera QR con código de sesión
- Jugadores escanean con cámara o input manual
- QR contiene: `rallyos://sync/{sessionCode}`

**Opción B: Nearby API (P1)**
- Bluetooth beacons para auto-discovery
- Más seamless pero más complejo

### 5.4 Storage

- **Local**: AsyncStorage para persistir última session (reconexión rápida)
- **No Supabase**: Este POC NO usa backend externo (zero dependencies)

---

## 6. POC Scope & Limitations

### 6.1 In Scope (MVP POC)

- ✅ Crear sesión como referee
- ✅ Generar código y QR
- ✅ Unirse con código (input manual)
- ✅ Configurar match: formato (2/3/5 sets), puntos (11/15/21)
- ✅ Marcar puntos (+1) y corregir errores (-1)
- ✅ Validación de set: 11 pts con 2 de diferencia
- ✅ Deuce mode: jugar hasta +2 desde 10-10
- ✅ Servicio alternado cada 2 puntos
- ✅ Cambio de lado entre sets
- ✅ Broadcast a viewers en tiempo real
- ✅ Historial de últimos puntos (para undo)
- ✅ Set won overlay animation
- ✅ Match won overlay con confetti
- ✅ Finalizar match
- ✅ Ver score en tiempo real (viewer)
- ✅ Manejo de desconexión/reconexión básica
- ✅ Haptic feedback

### 6.2 Out of Scope (POC)

- ❌ ELO calculation (viene después)
- ❌ Integración con Supabase (standalone)
- ❌ Persistencia de historial
- ❌ Multi-language
- ❌ Sonidos selain haptic
- ❌ Portrait/Landscape adaptation
- ❌ Offline queue (primera versión requiere conexión local)

### 6.3 Limitaciones Conocidas

1. **Rango WiFi**: En tournaments grandes, el referee debe estar físicamente cerca
2. **Un match a la vez**: POC solo soporta una sesión activa
3. **No hay autenticación**: Cualquiera con el código puede unirse
4. **Sin persistencia**: Al cerrar la app se pierde todo

---

## 7. Success Metrics (POC)

### 7.1 Funcionales

| Métrica | Target | Método de validación |
|---------|--------|---------------------|
| Sesión creada exitosamente | 100% | Test en torneo |
| Jugadores se conectan < 30s | 90% | Observación |
| Score visible en viewers < 1s | 95% | Medición manual |
| Undo funciona correctamente | 100% | Test cases |

### 7.2 Experiencia

| Métrica | Target | Feedback |
|---------|--------|----------|
| "Fácil de usar" (referee) | 8/10 | Survey post-torneo |
| "Me sirvió para seguir el match" (viewer) | 8/10 | Survey post-torneo |
| Preferiría esto vs papel | > 50% | Encuesta binaria |

### 7.3 Técnicos

| Métrica | Target |
|---------|--------|
| Crash rate | < 1% |
| Battery drain (referee) | < 20% por match |
| Compatible con iOS/Android | Ambos |

---

## 8. Next Steps (Post-POC)

1. **Integración con RallyOS Core**
   - Conectar con Supabase para persistencia
   - Activar ELO calculation post-match
   - Guardar historial de matches

2. **Features Avanzados**
   - Voice scoring ("Punto para A")
   - Multiple courts simultaneous
   - Spectator mode con stats en vivo

3. **Hardware Integration**
   - Scoreboard TV sync
   - External display support

---

## 9. Appendix: Screens Flow

```
                    ┌──────────────────┐
                    │   Entry Point    │
                    │  (No Session)    │
                    └────────┬─────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
              ▼                             ▼
    ┌─────────────────┐          ┌──────────────────┐
    │  Create Session │          │  Join Session     │
    │  (Referee)      │          │  (Player)        │
    └────────┬────────┘          └────────┬─────────┘
             │                            │
             ▼                            ▼
    ┌─────────────────┐          ┌──────────────────┐
    │  Waiting Room   │          │  Waiting Room     │
    │  (Referee)      │          │  (Player)         │
    └────────┬────────┘          └────────┬─────────┘
             │                            │
             │    (Match Started)         │
             │◄──────────────────────────►│
             │                            │
             ▼                            ▼
    ┌─────────────────┐          ┌──────────────────┐
    │  Scoreboard     │◄────────►│  Scoreboard      │
    │  (Referee)      │  Broadcast │  (Viewer)       │
    │  + Controls     │          │  Read-only       │
    └────────┬────────┘          └──────────────────┘
             │
             │ (Match Ended)
             ▼
    ┌─────────────────┐
    │  Match Summary  │
    │  (Winner/Cards) │
    └─────────────────┘
```

---

*Documento creado para iteración rápida en entorno de torneo semanal.*
