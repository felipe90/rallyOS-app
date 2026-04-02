# Flow: Bracket Management

Este flujo permite al organizador visualizar el árbol del torneo (Single Elimination, Round Robin) y registrar los ganadores de cada fase.

## User Intent: **Bracket Tracking** (CU-04)
El usuario quiere ver el avance real del torneo y poder tocar cualquier match para cargar el score o ver detalles. La legibilidad de los nodos es crítica.

## Flow Pathway

### 1. **Entry Point**
- **Trigger**: `Organizer Dashboard` -> Tab `Bracket`.
- **Screen**: `Bracket Canvas`.

### 2. **Visualization (Vibe Check)**
- **Action**: Zoom in/out y scroll horizontal sobre el canvas.
- **Component**: `BracketCanvas` (Lienzo infinito con Glassmorphism suave).

### 3. **Match Status Recording**
- **Action**: Tap en un `BracketNode`.
- **Micro-Interaction**: Se abre un `Contextual Overlay` (Bottom Sheet) con las stats del match.
- **Trigger**: Botón `Enter Score` -> Navega al flujo de `Live Scoring`.

### 4. **Progressive Advancement**
- **State**: Cuando un match termina (`FINISHED`), el ganador se mueve automáticamente al siguiente nodo del bracket con una animación de **Línea de Conexión Brillante** (Amber Glow).
- **Result**: Visualización del ganador final en la cima del bracket.

---

## Component Checklist (Top-Down)

- [ ] `BracketCanvas`: Contenedor reactivo con soporte para gestos de `Pinch & Zoom`.
- [ ] `BracketNode`: 
    - **Status**: DRAFT (Wait), LIVE (Pulse), FINISHED (Teal).
    - **Labels**: Nombres de los jugadores/equipos (`text-xs` o `text-sm`).
    - **Connector Lines**: Líneas de conexión con Gradientes dinámicos.
- [ ] `OutcomeModal`: Bottom Sheet con `PodiumIcon` y resumen de puntos.

## Interaction Design Standards

- **Tactile Feedback**: Animación sutil de "Glow" en el nodo ganador al terminar el match.
- **High-Tech Clubhouse**: Las líneas que conectan los nodos tienen un efecto de `Neon Core` cuando el match está en curso.
- **Edge Case**: Si hay un empate, el nodo muestra un icono de Warning alertando al organizador.
