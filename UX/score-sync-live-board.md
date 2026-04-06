# 🚧 POC: Score Sync Live Board

> **Estado**: POC (Proof of Concept)  
> **Versión**: 0.1.0  
> **Última actualización**: 2026-04-02  
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
[Referee] → [Tap Jugador] → [+1 Point] → [Broadcast] → [Todos los devices actualizan]
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
- Botones táctiles gigantes para cada jugador (50% pantalla)
- Indicador de quién tiene el servicio
- Botón "Undo" (último punto)
- Botón "Finalizar Match"
- Indicador de conexiones activas

**Estado Visual**:
```
┌─────────────────────────────┐
│  PADEL-4821  ●●● 3 conex.   │
├─────────────────────────────┤
│                             │
│       ⬆️ JUGADOR A          │
│         Miguel              │
│                             │
│       SET   GAME   PTS      │
│       ─────────────────     │
│         2      4     12     │
│                             │
│   ┌─────────────────────┐   │
│   │                     │   │
│   │      TAP PARA       │   │
│   │      +1 PUNTO       │   │
│   │                     │   │
│   │    [Haptic +1]      │   │
│   │                     │   │
│   └─────────────────────┘   │
│                             │
├─────────────────────────────┤
│   ┌─────────────────────┐   │
│   │                     │   │
│   │      TAP PARA       │   │
│   │      +1 PUNTO       │   │
│   │                     │   │
│   │    [Haptic +1]      │   │
│   │                     │   │
│   └─────────────────────┘   │
│                             │
│       SET   GAME   PTS      │
│       ─────────────────     │
│         1      3      8      │
│                             │
│       ⬇️ JUGADOR B           │
│         Pablo               │
│                             │
├─────────────────────────────┤
│  [↩️ Deshacer]    [🏁 Fin]   │
└─────────────────────────────┘
```

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

## 4. Component Inventory

### 4.1 Core Components

| Componente | Descripción | Estados |
|------------|-------------|---------|
| `SessionCodeInput` | Input de 6 dígitos custom | idle, focused, error, success |
| `QRCodeDisplay` | Generador de QR | loading, ready |
| `ConnectionIndicator` | Shows P2P status | connected (green), reconnecting (yellow), disconnected (red) |
| `ScoreDisplay` | Display gigante de score | normal, point-added (animation), winner (celebration) |
| `MassiveTapZone` | Zona táctil 50% | idle, pressed (scale-95), disabled |
| `UndoButton` | Deshacer último punto | idle, disabled (no history) |
| `EndMatchButton` | Finalizar match | idle, confirm-modal |
| `WaitingRoomList` | Lista de conectados | empty, populated |

### 4.2 Design Tokens

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
- ✅ Marcar puntos (+1)
- ✅ Broadcast a viewers
- ✅ Deshacer último punto
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
