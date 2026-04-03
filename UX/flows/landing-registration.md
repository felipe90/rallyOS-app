# Flow: Landing Page & Registration (Onboarding)

Este flujo es el embudo de conversión primario y el primer punto de contacto del usuario con RallyOS. Debe transmitir autoridad ("High-Tech Clubhouse") y reducir la fricción al mínimo operativo.

## User Intent: **Join the Community** (CU-09 / Onboarding)
El usuario quiere entender de qué trata la plataforma rápidamente y crearse una cuenta sin barreras innecesarias, pudiendo configurar su perfil competitivo posteriormente.

## Flow Pathway

### 1. **Entry Point (Landing Page)**
- **Trigger**: Navegación a la URL raíz.
- **Screen**: `Landing Hero`.
- **Content**: 
  - Logo central dominante (RallyOS / Stitch Vibe).
  - Copy fuerte y directo: "Evolve Your Game. Pro-Level Tournament Management."
  - Botón principal de acción única: `Get Started` (Redirecciona a Auth).

### 2. **Authentication (The Gate)**
- **Screen**: `Auth Modal / Overlay`.
- **Options**:
  - **Social Auth**: Opciones prominentes de `Continue with Google` / `Continue with Apple`.
  - **Traditional Auth**: Formularios colapsados de `Email & Password` (Login / Sign Up) debajo del divider "OR".
- **Interaction**: Autenticación manejada vía Supabase Auth.
- **State Transition**: Al tener token válido, verificación inmediata de estado del perfil.

### 3. **Profile Completion (First Time Only)**
- **Trigger**: Token válido PERO registro de tabla `users/profiles` incompleto o inexistente.
- **Screen**: `Profile Setup Step`.
- **Inputs Obligatorios**:
  - **Nickname / Display Name**: Identificador público en los brackets.
  - **Primary Sport**: Padel, Tennis, etc.
  - **Self-Assessed Level**: Nivel inicial sugerido (para asignación preliminar de ELO).
- **Component**: `GlassFormContainer` con un `StepIndicator` rápido.

### 4. **Welcome & Redirection**
- **Trigger**: Guardado exitoso del perfil.
- **Result**: Redirección inmediata al `Home Feed` (Flow: Home Feed & Discovery).

---

## Component Checklist (Top-Down)

- [ ] `LandingHero`: Fondo inmersivo (Slate-900 con glow Teal), Logo grande, CTA masivo.
- [ ] `AuthContainer`: Modal centrado, fondo desenfocado (Glassmorphism blur-md).
- [ ] `SocialAuthButton`: Botones anchos con iconos oficiales y feedback táctil (scale).
- [ ] `ProfileCompletionForm`: Formulario de 3 inputs, limpio, sin distracciones visuales.

## Interaction Design Standards

- **Low Friction**: Si el usuario usa Social Auth y ya tiene perfil, la pantalla de auth no dura más de 500ms y entra directo al Home.
- **Clear Separation**: El registro clásico (Email/Pass) no debe competir visualmente con el Social Auth; el Social Auth es la ruta preferida por UX.
- **Direct Tone**: Textos cortos y directivos. "Completa tu perfil" en lugar de textos largos descriptivos.
