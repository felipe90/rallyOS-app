# UI Patterns: "High-Tech Clubhouse"

Este documento define los componentes atómicos y patrones visuales que garantizan la consistencia del **Vibe Design** de Stitch en RallyOS.

## Visual Foundation (Tokens)

Referencia: `ui/theme.json`

| Token | Propósito | Clase NativeWind |
|-------|-----------|------------------|
| Primary | `#14B8A6` (Teal) | `text-primary` / `bg-primary` |
| Secondary | `#A7F3D0` (Mint) | `text-secondary` / `bg-secondary` |
| Tertiary | `#F59E0B` (Amber) | `text-tertiary` / `bg-tertiary` |
| Background | `#0F172A` (Slate Dark) | `bg-slate-900` |
| Surface | `#1E293B` (Slate Light) | `bg-slate-800` |

---

## Core UI Components (Design System)

### 1. **Glassmorphism Container**
Utilizado para tarjetas de torneos y paneles de control.
- **Background**: `bg-white/10` o `bg-slate-800/60`.
- **Blur**: `blur-sm` (vía `Expo Blur`).
- **Border**: `border-white/20` con `border-[1px]`.
- **Radius**: `rounded-2xl` o `rounded-3xl`.

### 2. **Tactile Primary Button**
- **Sombra**: `shadow-lg shadow-primary/20`.
- **Feedback**: Escalar al presionar (`scale-95`).
- **Typo**: `font-bold tracking-tight`.

### 3. **Live Scoreboard Toggles**
- **Tap Target**: Min `h-32`.
- **Feedback Visual**: Cambio instantáneo de color con `timing` de 150ms.
- **Typo Score**: `text-5xl font-black`.

---

## Tournament State Indicators (Badges)

Cada estado del torneo tiene su propio color y comportamiento visual:

| Estado | Color | Vibe |
|--------|-------|------|
| **DRAFT** | Gray | Placeholder / Quiet |
| **LIVE** | Amber | Glow / Pulsing / Fast |
| **FINISHED** | Teal | Checkmark / Solid / Celebration |
| **CANCELLED** | Red | Muted / Striking |

---

## Interaction Design Standards

### 1. **Optimistic States**
- El usuario toca `+1` → el UI se actualiza instantáneamente con un `scale-110` temporal.
- La confirmación con el servidor se maneja en background.

### 2. **Contextual Overlays**
- El registro a un torneo se abre en un `BottomSheet` (vía `gorhom/bottom-sheet`) con el fondo desenfocado.

### 3. **Empty States**
- Cuadrados vacíos con ilustración de "Cancha Vacía" y CTA prominente.
