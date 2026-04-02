# Flow: Post-Match Feedback & ELO

Este flujo representa el momento de "evolución" del jugador tras terminar un partido (CU-06). Incentiva la retención y el crecimiento competitivo.

## User Intent: **Progression & Social Proof** (CU-06)
El usuario quiere ver el impacto inmediato del match en su ELO y poder compartir su "proeza" de forma visualmente impactante. Los gradientes y animaciones de "subir de nivel" son la clave.

## Flow Pathway

### 1. **Entry Point**
- **Trigger**: Cierre del match en `Live Scoreboard` o notificación push.
- **Screen**: `Match Feedback Overly` (Blur modal).

### 2. **ELO Calculation (Visual Reveal)**
- **Action**: Ver el número de ELO actual y el Δ (incremento/decremento).
- **Micro-Interaction**: Un contador dinámico de números (`CounterText`) que sube o baja con un resplandor (Amber: Live/Up, Gray: Down).
- **Component**: `ELOUpdateSummary` (Centralizado con Glassmorphism).

### 3. **Achievement Badge**
- **Action**: Recibir un badge especial si el match fue crítico (e.g. "Giant Slayer" si le ganó a alguien de mayor ELO).
- **Component**: `AchievementBadge` (Icono animado flotante).

### 4. **Share Card Generation**
- **Action**: Tap en el botón `Share Achievement`.
- **Interaction**: Se genera un PNG on-the-fly con fondo "High-Tech Clubhouse".
- **Component**: `ShareCardGenerator` (Preview del layout de la imagen).

---

## Component Checklist (Top-Down)

- [ ] `MatchSummaryContainer`: Modal de pantalla completa con desenfoque de fondo.
- [ ] `ELOUpdateSummary`: 
    - **Header**: Resultado del match (WIN/LOSS).
    - **Counter**: El valor de ELO con animación de scroll de dígitos.
- [ ] `ShareCardGenerator`: 
    - **Branding**: Logo de RallyOS + Foto de perfil.
    - **Stats**: Resultado final del match y ELO ganado.
- [ ] `CloseButton`: Botón sutil en la parte inferior para volver al `Feed`.

## Interaction Design Standards

- **Personal Progress**: El UI debe sentirse como un videojuego (Gamification).
- **Viral Vibe**: El diseño de la `Share Card` debe ser impecable (Glassmorphism + Gradientes de alta calidad) para incentivar el posteo en Instagram/WhatsApp.
- **Tactile**: Vibración de "triunfo" prolongada si el usuario gana el match.
